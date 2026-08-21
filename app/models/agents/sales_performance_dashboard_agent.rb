module Agents
  class SalesPerformanceDashboardAgent < Agent
    include WebRequestConcern

    default_schedule "every_24h"

    description <<~MD
      The **SalesPerformanceDashboardAgent** fetches daily views, favourers, and orders from the
      Etsy API every morning and emits a shop stats event. It tracks weekly baselines to enable
      peak detection and revenue goal tracking.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `weekly_revenue_goal` — your weekly revenue target in GBP (default: 500)
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits:

          {
            "event_type": "daily_shop_stats",
            "total_active_listings": 45,
            "total_views_today": 312,
            "new_orders_today": 3,
            "revenue_today": 45.97,
            "week_revenue": 187.50,
            "revenue_goal": 500,
            "pct_to_goal": 37.5,
            "stats_date": "..."
          }
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
        'weekly_revenue_goal' => 500,
        'expected_update_period_in_days' => 2
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
      orders = fetch_todays_orders
      listings = fetch_active_listings
      total_views = listings.sum { |l| l['views'].to_i }
      revenue_today = orders.sum { |o| o.dig('total_price', 'amount').to_f / 100.0 }

      week_revenue = (memory['week_revenue_sum'] || 0.0) + revenue_today
      today = Date.today
      if (memory['week_start_date'].to_s != today.beginning_of_week.to_s)
        week_revenue = revenue_today
        memory['week_start_date'] = today.beginning_of_week.to_s
      end
      memory['week_revenue_sum'] = week_revenue
      save!

      goal = interpolated['weekly_revenue_goal'].to_f
      pct = goal.positive? ? [(week_revenue / goal * 100).round(1), 999].min : 0

      create_event payload: {
        'event_type' => 'daily_shop_stats',
        'total_active_listings' => listings.size,
        'total_views_today' => total_views,
        'new_orders_today' => orders.size,
        'revenue_today' => revenue_today.round(2),
        'week_revenue' => week_revenue.round(2),
        'revenue_goal' => goal,
        'pct_to_goal' => pct,
        'stats_date' => today.to_s
      }
    end

    private

    def fetch_todays_orders
      since = Date.today.to_time.to_i
      response = faraday.get(
        "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/receipts",
        { min_created: since, limit: 100 },
        { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}" }
      )
      return [] unless response.success?

      JSON.parse(response.body)['results'] || []
    rescue StandardError => e
      error("SalesPerformanceDashboardAgent orders error: #{e.message}")
      []
    end

    def fetch_active_listings
      response = faraday.get(
        "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/listings",
        { state: 'active', limit: 100 },
        { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}" }
      )
      return [] unless response.success?

      JSON.parse(response.body)['results'] || []
    rescue StandardError => e
      error("SalesPerformanceDashboardAgent listings error: #{e.message}")
      []
    end
  end
end
