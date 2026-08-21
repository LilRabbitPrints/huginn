module Agents
  class DailyStatsAgent < Agent
    include EmailConcern

    cannot_be_scheduled!

    description <<~MD
      The **DailyStatsAgent** receives daily_shop_stats events and formats them into a clean
      8am morning briefing email showing what sold, revenue progress, and key metrics.

      **Options:**
      - `recipients` — email address(es) for the daily stats email
      - `expected_receive_period_in_days` — for health check
    MD

    def default_options
      {
        'recipients' => [],
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
      incoming_events.each do |event|
        payload = event.payload
        next unless payload['event_type'] == 'daily_shop_stats'

        send_daily_stats_email(payload)
      end
    end

    private

    def send_daily_stats_email(payload)
      goal_bar = progress_bar(payload['pct_to_goal'].to_f)
      body = <<~HTML
        <h2>🐇 Good morning! Here's your daily shop update</h2>
        <table cellpadding="8">
          <tr><td>📦 Orders today</td><td><strong>#{payload['new_orders_today']}</strong></td></tr>
          <tr><td>💰 Revenue today</td><td><strong>£#{payload['revenue_today']}</strong></td></tr>
          <tr><td>👀 Total listing views</td><td><strong>#{payload['total_views_today']}</strong></td></tr>
          <tr><td>📊 Week revenue</td><td><strong>£#{payload['week_revenue']}</strong> / £#{payload['revenue_goal']} goal</td></tr>
          <tr><td>🎯 Goal progress</td><td>#{goal_bar} #{payload['pct_to_goal']}%</td></tr>
          <tr><td>🏪 Active listings</td><td><strong>#{payload['total_active_listings']}</strong></td></tr>
        </table>
        <p><a href="https://www.etsy.com/your/shops/me/dashboard">View Etsy Dashboard →</a></p>
      HTML

      recipients.each do |recipient|
        SystemMailer.send_message(
          to: recipient, from: ENV['EMAIL_FROM_ADDRESS'],
          subject: "🐇 Daily Update: #{payload['new_orders_today']} orders · £#{payload['revenue_today']} today",
          headline: nil, body: body, content_type: 'text/html', groups: []
        ).deliver_now
        log("Sent daily stats to #{recipient}")
      rescue StandardError => e
        error("DailyStatsAgent email error: #{e.message}")
      end
    end

    def progress_bar(pct)
      filled = [(pct / 10).to_i, 10].min
      empty = 10 - filled
      ('█' * filled) + ('░' * empty)
    end
  end
end
