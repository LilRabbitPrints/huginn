module Agents
  class WeeklySeoBeliefAgent < Agent
    include EmailConcern

    default_schedule "every_7d"

    description <<~MD
      The **WeeklySeoBeliefAgent** synthesises all SEO data collected during the week — gap
      analysis, audit results, trending keywords, and win tracking — and delivers your
      weekly SEO action plan every Monday morning.

      It emits a `weekly_seo_brief` event and sends an email digest.

      **Options:**
      - `recipients` — email address(es) to send the brief to
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "weekly_seo_brief", top_opportunities: [...], new_keywords: [...], seasonal_flags: [...], wins: [...]}`.
    MD

    def default_options
      {
        'recipients' => [],
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
      incoming_events.each do |event|
        payload = event.payload
        type = payload['event_type']
        case type
        when 'gap_analysis'
          memory['gap_analysis'] = payload
        when 'tag_inventory'
          memory['tag_inventory'] = payload
        when 'consolidated_keywords'
          memory['keyword_list'] = payload['keyword_list']
        when 'listing_seo_audit'
          audits = memory['audits'] ||= []
          audits << payload
          memory['audits'] = audits.last(200)
        end
        save!
      end
    end

    def check
      brief = build_brief
      create_event payload: brief
      send_brief_email(brief)
    end

    private

    def build_brief
      {
        'event_type' => 'weekly_seo_brief',
        'top_opportunities' => top_opportunity_listings,
        'new_keywords' => new_keyword_targets,
        'seasonal_flags' => seasonal_opportunities,
        'generated_at' => Time.now.utc.iso8601
      }
    end

    def top_opportunity_listings
      audits = memory['audits'] || []
      audits.select { |a| !a['audit_passed'] && a['audit_score'].to_i >= 50 }
            .sort_by { |a| -a['audit_score'].to_i }.first(3)
            .map { |a| { 'listing_id' => a['listing_id'], 'title' => a['title'], 'score' => a['audit_score'], 'top_issue' => a['failures']&.first } }
    end

    def new_keyword_targets
      (memory['keyword_list'] || []).first(3).map { |k| k['keyword'] }
    end

    def seasonal_opportunities
      upcoming = []
      today = Date.today
      occasions = [
        [Date.new(today.year, 2, 14), 'Valentine\'s Day — promote rabbit couple prints'],
        [Date.new(today.year, 4, 1), 'Easter — promote easter bunny gifts'],
        [Date.new(today.year, 3, 31) + (7 - Date.new(today.year, 3, 31).wday), 'Mother\'s Day (April) — personalised gifts'],
        [Date.new(today.year, 12, 25), 'Christmas — bulk corporate gifts']
      ]
      occasions.each do |date, label|
        weeks_away = ((date - today) / 7).to_i
        upcoming << { 'occasion' => label, 'weeks_away' => weeks_away } if weeks_away.between?(1, 8)
      end
      upcoming
    end

    def send_brief_email(brief)
      body = build_email_html(brief)
      recipients.each do |recipient|
        SystemMailer.send_message(
          to: recipient,
          from: ENV['EMAIL_FROM_ADDRESS'],
          subject: "🐇 Your Weekly SEO Brief — #{Date.today.strftime('%d %b %Y')}",
          headline: nil,
          body: body,
          content_type: 'text/html',
          groups: []
        ).deliver_now
      rescue StandardError => e
        error("WeeklySeoBeliefAgent email error: #{e.message}")
      end
    end

    def build_email_html(brief)
      opps = brief['top_opportunities'].map { |o| "<li>Listing #{o['listing_id']}: #{o['title']&.truncate(50)} (score: #{o['score']}) — fix: #{o['top_issue']}</li>" }.join
      kws = brief['new_keywords'].map { |k| "<li>#{k}</li>" }.join
      seasons = brief['seasonal_flags'].map { |s| "<li>#{s['occasion']} (#{s['weeks_away']} weeks away)</li>" }.join
      <<~HTML
        <h2>🐇 Weekly SEO Brief</h2>
        <h3>🎯 Top 3 Listing Opportunities</h3><ul>#{opps.presence || '<li>All listings looking good!</li>'}</ul>
        <h3>🔑 New Keywords to Target This Week</h3><ul>#{kws.presence || '<li>Check back after keyword research runs</li>'}</ul>
        <h3>📅 Upcoming Seasonal Opportunities</h3><ul>#{seasons.presence || '<li>No seasonal events in next 8 weeks</li>'}</ul>
      HTML
    end
  end
end
