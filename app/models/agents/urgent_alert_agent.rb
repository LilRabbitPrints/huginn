require 'net/smtp'

module Agents
  class UrgentAlertAgent < Agent
    include EmailConcern

    cannot_be_scheduled!

    description <<~MD
      The **UrgentAlertAgent** fires instant email/push notifications for critical events:
      - New 5-star review received
      - Bulk inquiry detected
      - Traffic spike (>2× average)
      - New listing went live

      It sends an immediate email with a clear subject line and concise body so you can
      respond or capitalise within minutes.

      **Options:**
      - `recipients` — email address(es) for urgent alerts
      - `urgent_event_types` — array of event types that trigger immediate notification
      - `expected_receive_period_in_days` — for health check
    MD

    def default_options
      {
        'recipients' => [],
        'urgent_event_types' => %w[traffic_spike bulk_inquiry_detected listing_activated stuck_listing_alert new_5star_review],
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
      urgent = interpolated['urgent_event_types'] || []
      incoming_events.each do |event|
        payload = event.payload
        next unless urgent.include?(payload['event_type'].to_s)

        subject, body = build_notification(payload)
        recipients.each do |recipient|
          SystemMailer.send_message(
            to: recipient, from: ENV['EMAIL_FROM_ADDRESS'],
            subject: subject, headline: nil, body: body, content_type: 'text/html', groups: []
          ).deliver_now
          log("UrgentAlertAgent: sent #{payload['event_type']} alert to #{recipient}")
        rescue StandardError => e
          error("UrgentAlertAgent error: #{e.message}")
        end
      end
    end

    private

    def build_notification(payload)
      case payload['event_type']
      when 'traffic_spike'
        subject = "🚀 Traffic spike! #{payload['multiplier']}× normal — post NOW"
        body = "<p>#{payload['alert']}</p><p>Views today: #{payload['views_today']} (average: #{payload['average_views']})</p><p><a href='https://www.etsy.com/your/shops/me/dashboard'>View Dashboard</a></p>"
      when 'bulk_inquiry_detected'
        subject = "📦 Bulk inquiry from #{payload['buyer_name']}"
        body = "<p><strong>Buyer:</strong> #{payload['buyer_name']}</p><p><strong>Message:</strong> #{payload['message_preview']}</p><p><strong>Keywords:</strong> #{payload['detected_keywords']&.join(', ')}</p>"
      when 'listing_activated'
        subject = "✅ New listing live: #{payload['title']&.truncate(50)}"
        body = "<p><a href='#{payload['listing_url']}'>#{payload['listing_url']}</a></p>"
      when 'stuck_listing_alert'
        subject = "⚠️ Stuck listing: #{payload['listing_id']} in #{payload['current_state']}"
        body = "<p>#{payload['alert']}</p>"
      else
        subject = "🐇 Alert: #{payload['event_type']}"
        body = "<pre>#{payload.to_json}</pre>"
      end
      [subject, body]
    end
  end
end
