require 'net/smtp'

module Agents
  class ActionRequiredAgent < Agent
    include EmailConcern

    cannot_be_scheduled!

    description <<~MD
      The **ActionRequiredAgent** aggregates all items awaiting your approval or attention into
      a single daily "your attention needed" email. This prevents you from missing time-sensitive
      approvals scattered across different notifications.

      Items collected:
      - Draft listings awaiting activation
      - Bulk quote drafts awaiting your review
      - Tag swap suggestions ready to implement
      - Follow-up messages ready to send
      - Listings that failed audit and need re-optimisation

      **Options:**
      - `recipients` — email address(es) for the action required digest
      - `send_hour_utc` — UTC hour to send the digest (default: 9)
      - `expected_receive_period_in_days` — for health check
    MD

    def default_options
      {
        'recipients' => [],
        'send_hour_utc' => 9,
        'expected_receive_period_in_days' => 2
      }
    end

    def validate_options
      errors.add(:base, 'recipients must be provided') if options['recipients'].blank?
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      action_types = %w[draft_ready bulk_quote_draft tag_swap_suggestions bulk_follow_up_draft listing_seo_audit]
      buffer = memory['buffer'] ||= []

      incoming_events.each do |event|
        type = event.payload['event_type'].to_s
        next unless action_types.include?(type) ||
                    (type == 'listing_seo_audit' && !event.payload['audit_passed'])

        buffer << event.payload.merge('queued_at' => Time.now.utc.iso8601)
      end

      memory['buffer'] = buffer.last(100)
      save!
      maybe_send!
    end

    private

    def maybe_send!
      today = Date.today.to_s
      last_sent = memory['last_sent']
      return if last_sent == today || Time.now.utc.hour < interpolated['send_hour_utc'].to_i

      buffer = memory['buffer'] || []
      return if buffer.empty?

      body = build_action_email(buffer)
      recipients.each do |recipient|
        SystemMailer.send_message(
          to: recipient, from: ENV['EMAIL_FROM_ADDRESS'],
          subject: "🐇 #{buffer.size} items need your attention today — Lil Rabbit Prints",
          headline: nil, body: body, content_type: 'text/html', groups: []
        ).deliver_now
        log("ActionRequiredAgent: sent #{buffer.size} action items to #{recipient}")
      rescue StandardError => e
        error("ActionRequiredAgent error: #{e.message}")
      end

      memory['buffer'] = []
      memory['last_sent'] = today
      save!
    end

    def build_action_email(buffer)
      groups = buffer.group_by { |p| p['event_type'] }
      sections = ["<h2>🐇 Your Action Items for Today</h2>"]

      if (drafts = groups['draft_ready'])
        items = drafts.map { |p| "<li><a href='#{p['draft_url']}'>#{p['title']&.truncate(60)}</a> — <a href='#{approve_url(p)}'>✅ Approve & Activate</a></li>" }.join
        sections << "<h3>📝 Draft Listings Awaiting Activation (#{drafts.size})</h3><ul>#{items}</ul>"
      end

      if (quotes = groups['bulk_quote_draft'])
        items = quotes.map { |p| "<li><strong>#{p['buyer_name']}</strong><br><em>#{p['draft_response']&.truncate(150)}</em></li>" }.join
        sections << "<h3>📦 Bulk Quote Drafts to Send (#{quotes.size})</h3><ul>#{items}</ul>"
      end

      if (swaps = groups['tag_swap_suggestions'])
        items = swaps.map { |p| "<li>#{p['listing_title']&.truncate(50)}: #{(p['swaps'] || []).map { |s| "#{s['remove']} → #{s['add']}" }.join(', ')}</li>" }.join
        sections << "<h3>🏷️ Tag Swaps to Apply (#{swaps.size} listings)</h3><ul>#{items}</ul>"
      end

      if (follow_ups = groups['bulk_follow_up_draft'])
        items = follow_ups.map { |p| "<li><strong>#{p['buyer_name']}</strong> (attempt #{p['attempt']})<br><em>#{p['follow_up_text']&.truncate(120)}</em></li>" }.join
        sections << "<h3>💬 Follow-Up Messages to Review (#{follow_ups.size})</h3><ul>#{items}</ul>"
      end

      sections.join
    end

    def approve_url(payload)
      new_id = payload['new_listing_id'] || payload['listing_id']
      "https://www.etsy.com/listing/#{new_id}"
    end
  end
end
