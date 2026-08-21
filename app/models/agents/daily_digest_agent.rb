require 'net/smtp'

module Agents
  class DailyDigestAgent < Agent
    include EmailConcern

    cannot_be_scheduled!

    description <<~MD
      The **DailyDigestAgent** collects events throughout the day and sends an 8am daily
      summary email showing:
      - What sold overnight
      - What was posted on social media
      - What's currently in the pipeline (per-state counts)
      - Any promotions fired
      - Revenue progress toward weekly goal

      **Options:**
      - `recipients` — email address(es) for the daily digest
      - `send_hour_utc` — UTC hour to send the digest (default: 8)
      - `expected_receive_period_in_days` — for health check
    MD

    def default_options
      {
        'recipients' => [],
        'send_hour_utc' => 8,
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
      buffer = memory['buffer'] ||= []
      incoming_events.each { |e| buffer << e.payload }
      memory['buffer'] = buffer.last(200)
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

      body = build_digest(buffer)
      stats = buffer.find { |p| p['event_type'] == 'daily_shop_stats' }
      orders = stats&.dig('new_orders_today') || 0
      revenue = stats&.dig('revenue_today') || 0

      recipients.each do |recipient|
        SystemMailer.send_message(
          to: recipient, from: ENV['EMAIL_FROM_ADDRESS'],
          subject: "🐇 Daily Digest: #{orders} orders · £#{revenue} — #{Date.today.strftime('%d %b')}",
          headline: nil, body: body, content_type: 'text/html', groups: []
        ).deliver_now
        log("DailyDigestAgent: sent digest to #{recipient}")
      rescue StandardError => e
        error("DailyDigestAgent error: #{e.message}")
      end

      memory['buffer'] = []
      memory['last_sent'] = today
      save!
    end

    def build_digest(buffer)
      groups = buffer.group_by { |p| p['event_type'] }
      sections = []

      if (stats = groups['daily_shop_stats']&.last)
        sections << "<h3>📊 Shop Stats</h3><p>Orders: #{stats['new_orders_today']} · Revenue: £#{stats['revenue_today']} · Views: #{stats['total_views_today']} · Goal: #{stats['pct_to_goal']}%</p>"
      end

      promotions = groups['promotion_trigger'] || []
      if promotions.any?
        items = promotions.map { |p| "<li>#{p['title']&.truncate(60)}</li>" }.join
        sections << "<h3>📢 Promotions Sent</h3><ul>#{items}</ul>"
      end

      state_changes = groups['state_transition'] || []
      if state_changes.any?
        items = state_changes.map { |s| "<li>Listing #{s['listing_id']}: #{s['from_state']} → #{s['to_state']}</li>" }.join
        sections << "<h3>🔄 Pipeline Activity</h3><ul>#{items}</ul>"
      end

      sections << "<p><a href='https://www.etsy.com/your/shops/me/dashboard'>View Etsy Dashboard →</a></p>"
      sections.join
    end
  end
end
