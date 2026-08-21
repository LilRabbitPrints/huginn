require 'net/smtp'

module Agents
  class NotificationCenterAgent < Agent
    include EmailConcern

    cannot_be_scheduled!

    description <<~MD
      The **NotificationCenterAgent** is the central hub for all alerts, digests, and reports
      from across the Lil Rabbit Prints pipeline. It routes incoming events to the appropriate
      notification sub-agents and aggregates all pending action items.

      It distinguishes between:
      - **Urgent** events (new review, bulk inquiry, traffic spike, listing live) → instant email
      - **Daily digest** events → buffered until 8am daily briefing
      - **Weekly report** events → buffered until Sunday evening report
      - **Action required** events → buffered into a daily approval queue email

      **Options:**
      - `recipients` — email address(es) for all notifications
      - `urgent_event_types` — array of event_type values that trigger instant email
      - `expected_receive_period_in_days` — for health check
    MD

    def default_options
      {
        'recipients' => [],
        'urgent_event_types' => %w[traffic_spike bulk_inquiry_detected listing_activated stuck_listing_alert],
        'expected_receive_period_in_days' => 1
      }
    end

    def validate_options
      errors.add(:base, 'recipients must be provided') if options['recipients'].blank?
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      urgent_types = interpolated['urgent_event_types'] || []
      daily_buffer = memory['daily_buffer'] ||= []
      weekly_buffer = memory['weekly_buffer'] ||= []
      action_buffer = memory['action_buffer'] ||= []

      incoming_events.each do |event|
        payload = event.payload
        type = payload['event_type'].to_s

        if urgent_types.include?(type)
          send_urgent_notification(payload)
        elsif type.start_with?('bulk_quote_draft', 'tag_swap_suggestions', 'listing_history_response')
          action_buffer << payload
        elsif type.start_with?('weekly_seo_brief', 'seo_wins', 'top_listings_report')
          weekly_buffer << payload
        else
          daily_buffer << payload
        end
      end

      memory['daily_buffer'] = daily_buffer.last(100)
      memory['weekly_buffer'] = weekly_buffer.last(50)
      memory['action_buffer'] = action_buffer.last(50)
      save!
    end

    private

    def send_urgent_notification(payload)
      subject = build_urgent_subject(payload)
      body = "<pre>#{payload.to_json}</pre>"
      recipients.each do |recipient|
        SystemMailer.send_message(
          to: recipient, from: ENV['EMAIL_FROM_ADDRESS'],
          subject: subject, headline: nil, body: body, content_type: 'text/html', groups: []
        ).deliver_now
        log("NotificationCenterAgent: sent urgent alert (#{payload['event_type']}) to #{recipient}")
      rescue StandardError => e
        error("NotificationCenterAgent urgent email error: #{e.message}")
      end
    end

    def build_urgent_subject(payload)
      case payload['event_type']
      when 'traffic_spike' then "🚀 #{payload['alert']}"
      when 'bulk_inquiry_detected' then "📦 Bulk inquiry from #{payload['buyer_name']}"
      when 'listing_activated' then "✅ New listing live: #{payload['title']&.truncate(50)}"
      when 'stuck_listing_alert' then "⚠️ #{payload['alert']}"
      else "🐇 Alert: #{payload['event_type']}"
      end
    end
  end
end
