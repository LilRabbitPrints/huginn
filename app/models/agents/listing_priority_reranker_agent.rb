module Agents
  class ListingPriorityRerankerAgent < Agent
    include WebRequestConcern

    default_schedule "every_24h"

    description <<~MD
      The **ListingPriorityRerankerAgent** re-scores the revival queue daily as new views and
      favourers data comes in from Etsy. This ensures the highest-potential listings always float
      to the top of the queue.

      It fetches the current inactive listings from Etsy, recalculates revival scores, and
      updates the priority order stored in memory for EtsyListingSchedulerAgent to consume.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `views_weight` — weight for views in score (default: 1)
      - `favorers_weight` — weight for favourers (default: 3)
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "priority_queue_updated", top_listings: [...], reranked_at: ...}`.
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
        'views_weight' => 1,
        'favorers_weight' => 3,
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
      listings = fetch_inactive_listings
      scored = listings.map do |l|
        score = l['views'].to_f * interpolated['views_weight'].to_f +
                l['num_favorers'].to_f * interpolated['favorers_weight'].to_f
        l.merge('revival_score' => score.round(2))
      end.sort_by { |l| -l['revival_score'] }

      memory['priority_queue'] = scored.map { |l| l.slice('listing_id', 'title', 'revival_score', 'views', 'num_favorers') }
      save!

      create_event payload: {
        'event_type' => 'priority_queue_updated',
        'top_listings' => scored.first(10).map { |l| l.slice('listing_id', 'title', 'revival_score') },
        'total_inactive' => scored.size,
        'reranked_at' => Time.now.utc.iso8601
      }
    end

    private

    def fetch_inactive_listings
      response = faraday.get(
        "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/listings",
        { state: 'inactive', limit: 100 },
        { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}" }
      )
      return [] unless response.success?

      JSON.parse(response.body)['results'] || []
    rescue StandardError => e
      error("ListingPriorityRerankerAgent: #{e.message}")
      []
    end
  end
end
