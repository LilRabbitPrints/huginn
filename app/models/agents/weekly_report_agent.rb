require 'net/smtp'

module Agents
  class WeeklyReportAgent < Agent
    include EmailConcern

    default_schedule "0 18 * * 0"

    description <<~MD
      The **WeeklyReportAgent** runs every Sunday at 6pm and compiles the full weekly
      performance report covering:
      - Total revenue vs goal
      - Top 3 performing listings
      - SEO wins and regressions
      - Social media promotions fired (and their lift)
      - Bulk order pipeline summary
      - Next week's priority actions

      **Options:**
      - `recipients` — email address(es) for the weekly report
      - `weekly_revenue_goal` — your target (for context in the report)
      - `expected_update_period_in_days` — for health check
    MD

    def default_options
      {
        'recipients' => [],
        'weekly_revenue_goal' => 500,
        'expected_update_period_in_days' => 8
      }
    end

    def validate_options
      errors.add(:base, 'recipients must be provided') if options['recipients'].blank?
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def receive(incoming_events)
      buffer = memory['weekly_buffer'] ||= []
      incoming_events.each { |e| buffer << e.payload }
      memory['weekly_buffer'] = buffer.last(300)
      save!
    end

    def check
      buffer = memory['weekly_buffer'] || []
      body = build_weekly_report(buffer)
      goal = interpolated['weekly_revenue_goal'].to_f
      stats = buffer.find { |p| p['event_type'] == 'daily_shop_stats' }
      week_rev = stats&.dig('week_revenue') || 0
      pct = goal.positive? ? (week_rev.to_f / goal * 100).round(0) : 0

      recipients.each do |recipient|
        SystemMailer.send_message(
          to: recipient, from: ENV['EMAIL_FROM_ADDRESS'],
          subject: "🐇 Weekly Report: £#{week_rev} / £#{goal.to_i} (#{pct}%) — #{Date.today.strftime('%d %b %Y')}",
          headline: nil, body: body, content_type: 'text/html', groups: []
        ).deliver_now
        log("WeeklyReportAgent: sent weekly report to #{recipient}")
      rescue StandardError => e
        error("WeeklyReportAgent error: #{e.message}")
      end

      memory['weekly_buffer'] = []
      save!
    end

    private

    def build_weekly_report(buffer)
      groups = buffer.group_by { |p| p['event_type'] }
      sections = ["<h2>🐇 Lil Rabbit Prints — Weekly Report</h2>"]

      if (stats = groups['daily_shop_stats']&.last)
        sections << "<h3>💰 Revenue</h3><p>Week total: £#{stats['week_revenue']} / £#{interpolated['weekly_revenue_goal']} goal (#{stats['pct_to_goal']}%)</p>"
      end

      if (top = groups['top_listings_report']&.last)
        items = (top['top_listings'] || []).map { |l| "<li>#{l['title']&.truncate(50)} — #{l['views']} views</li>" }.join
        sections << "<h3>🏆 Top Listings</h3><ul>#{items}</ul>"
      end

      if (seo = groups['seo_wins']&.last)
        wins = (seo['wins'] || []).map { |w| "<li>#{w['title']&.truncate(50)}: +#{w['views_change_pct']}% views</li>" }.join
        sections << "<h3>📈 SEO Wins</h3><ul>#{wins.presence || '<li>Keep optimising!</li>'}</ul>"
      end

      lifts = groups['promotion_lift_report'] || []
      if lifts.any?
        items = lifts.map { |l| "<li>#{l['title']&.truncate(40)}: +#{l['views_lift']} views, +#{l['favorers_lift']} favs</li>" }.join
        sections << "<h3>📢 Promotion Lifts</h3><ul>#{items}</ul>"
      end

      sections << "<p><a href='https://www.etsy.com/your/shops/me/dashboard'>View Etsy Dashboard →</a></p>"
      sections.join
    end
  end
end
