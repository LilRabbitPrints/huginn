require 'net/smtp'

module Agents
  class BulkOrderTrackerAgent < Agent
    include EmailConcern

    cannot_be_scheduled!

    description <<~MD
      The **BulkOrderTrackerAgent** logs all bulk inquiries, quote status, follow-up attempts,
      and outcomes in a running digest. It collects events from BulkQuoteDrafterAgent,
      BulkFollowUpAgent, and any closure events, then emails you a weekly bulk order pipeline
      report every Friday.

      **Options:**
      - `recipients` — email address(es) for the weekly digest
      - `send_day` — day of week for digest (5 = Friday, default: 5)
      - `send_hour_utc` — UTC hour to send (default: 8)
      - `expected_receive_period_in_days` — for health check
    MD

    def default_options
      {
        'recipients' => [],
        'send_day' => 5,
        'send_hour_utc' => 8,
        'expected_receive_period_in_days' => 7
      }
    end

    def validate_options
      errors.add(:base, 'recipients must be provided') if options['recipients'].blank?
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      log_map = memory['bulk_log'] ||= {}
      incoming_events.each do |event|
        payload = event.payload
        conv_id = payload['conversation_id'].to_s
        next if conv_id.blank?

        log_map[conv_id] ||= { 'conversation_id' => conv_id, 'events' => [], 'buyer_name' => payload['buyer_name'] }
        log_map[conv_id]['events'] << {
          'type' => payload['event_type'],
          'timestamp' => Time.now.utc.iso8601
        }
        log_map[conv_id]['status'] = derive_status(log_map[conv_id]['events'])
      end
      memory['bulk_log'] = log_map
      save!
      maybe_send_digest!
    end

    private

    def maybe_send_digest!
      today = Date.today
      last_sent = memory['last_sent']
      now = Time.now.utc
      return if last_sent == today.to_s
      return unless now.wday == interpolated['send_day'].to_i && now.hour >= interpolated['send_hour_utc'].to_i

      log_map = memory['bulk_log'] || {}
      return if log_map.empty?

      body = build_digest_html(log_map)
      recipients.each do |recipient|
        SystemMailer.send_message(
          to: recipient, from: ENV['EMAIL_FROM_ADDRESS'],
          subject: "🐇 Bulk Order Pipeline Report — #{today.strftime('%d %b %Y')}",
          headline: nil, body: body, content_type: 'text/html', groups: []
        ).deliver_now
        log("Sent bulk order digest to #{recipient}")
      rescue StandardError => e
        error("BulkOrderTrackerAgent email error: #{e.message}")
      end
      memory['last_sent'] = today.to_s
      save!
    end

    def build_digest_html(log_map)
      rows = log_map.values.map do |entry|
        "<tr><td>#{entry['conversation_id']}</td><td>#{entry['buyer_name']}</td><td>#{entry['status']}</td><td>#{entry['events'].size}</td></tr>"
      end.join
      <<~HTML
        <h2>🐇 Bulk Order Pipeline Report</h2>
        <table border="1" cellpadding="4"><thead><tr><th>Conversation</th><th>Buyer</th><th>Status</th><th>Events</th></tr></thead>
        <tbody>#{rows}</tbody></table>
      HTML
    end

    def derive_status(events)
      types = events.map { |e| e['type'] }
      return 'closed' if types.include?('bulk_inquiry_closed')
      return 'followed_up' if types.include?('bulk_follow_up_draft')
      return 'quoted' if types.include?('bulk_quote_draft')

      'detected'
    end
  end
end
