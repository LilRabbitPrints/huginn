module Agents
  class ReviewRefreshSchedulerAgent < Agent
    default_schedule "every_30d"

    description <<~MD
      The **ReviewRefreshSchedulerAgent** runs monthly and triggers a refresh of the social proof
      image (slot 7) for all active listings. It emits refresh trigger events containing each
      listing ID so downstream ReviewScraperAgent → ReviewPickerAgent → ReviewFormatterAgent
      agents can update the review quote with the most recent 5-star reviews.

      This ensures your social proof images stay fresh and don't show outdated reviews.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits one event per active listing:

          {
            "event_type": "review_refresh_trigger",
            "listing_id": 1234567890,
            "triggered_at": "2026-01-01T08:00:00Z"
          }
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
        'expected_update_period_in_days' => 32
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
      listing_ids = fetch_active_listing_ids
      listing_ids.each do |listing_id|
        create_event payload: {
          'event_type' => 'review_refresh_trigger',
          'listing_id' => listing_id,
          'triggered_at' => Time.now.utc.iso8601
        }
      end
      log("ReviewRefreshSchedulerAgent triggered refresh for #{listing_ids.size} listings")
    end

    private

    def fetch_active_listing_ids
      return [] if interpolated['shop_id'].blank?

      response = faraday_agent.get(
        "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/listings",
        { state: 'active', limit: 100 },
        { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}" }
      )
      return [] unless response.success?

      (JSON.parse(response.body)['results'] || []).map { |l| l['listing_id'] }
    rescue StandardError => e
      error("ReviewRefreshSchedulerAgent fetch error: #{e.message}")
      []
    end

    def faraday_agent
      require 'faraday'
      Faraday.new { |f| f.adapter Faraday.default_adapter }
    end
  end
end
