module Agents
  class SeoWinTrackerAgent < Agent
    include WebRequestConcern

    default_schedule "every_7d"

    description <<~MD
      The **SeoWinTrackerAgent** compares current listing views and favourers against the
      previous week's figures to identify SEO wins — listings that improved significantly
      after optimisation. It celebrates improvements and flags any regressions.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `win_threshold_pct` — minimum % view increase to classify as a win (default: 20)
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "seo_wins", wins: [...], regressions: [...], week_of: "..."}`.
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
        'win_threshold_pct' => 20,
        'expected_update_period_in_days' => 8
      }
    end

    def validate_options
      errors.add(:base, 'shop_id is required') if options['shop_id'].blank?
      errors.add(:base, 'api_key is required') if options['api_key'].blank?
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def check
      current = fetch_listing_stats
      previous = memory['previous_stats'] || {}
      threshold = interpolated['win_threshold_pct'].to_f / 100.0

      wins = []
      regressions = []

      current.each do |listing_id, stats|
        prev = previous[listing_id]
        next unless prev

        prev_views = prev['views'].to_i
        curr_views = stats['views'].to_i
        next if prev_views.zero?

        change_pct = (curr_views - prev_views).to_f / prev_views
        if change_pct >= threshold
          wins << { 'listing_id' => listing_id, 'title' => stats['title'], 'views_change_pct' => (change_pct * 100).round(1), 'views' => curr_views }
        elsif change_pct <= -threshold
          regressions << { 'listing_id' => listing_id, 'title' => stats['title'], 'views_change_pct' => (change_pct * 100).round(1), 'views' => curr_views }
        end
      end

      create_event payload: {
        'event_type' => 'seo_wins',
        'wins' => wins.sort_by { |w| -w['views_change_pct'] },
        'regressions' => regressions,
        'total_listings_tracked' => current.size,
        'week_of' => Date.today.to_s
      }

      memory['previous_stats'] = current
      save!
    end

    private

    def fetch_listing_stats
      response = faraday.get(
        "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/listings",
        { state: 'active', limit: 100 },
        { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}" }
      )
      return {} unless response.success?

      (JSON.parse(response.body)['results'] || []).each_with_object({}) do |l, h|
        h[l['listing_id'].to_s] = { 'views' => l['views'], 'title' => l['title'] }
      end
    rescue StandardError => e
      error("SeoWinTrackerAgent: #{e.message}")
      {}
    end
  end
end
