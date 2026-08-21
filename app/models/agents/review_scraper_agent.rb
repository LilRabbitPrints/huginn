module Agents
  class ReviewScraperAgent < Agent
    include WebRequestConcern

    default_schedule "every_12h"

    description <<~MD
      The **ReviewScraperAgent** fetches the latest 5-star reviews from your Etsy shop via the
      Etsy v3 API and emits each review as an event for downstream selection and formatting agents.

      It caches seen reviews in memory to only emit new ones on subsequent runs.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `min_rating` — minimum star rating to emit (default: 5)
      - `limit` — max reviews per fetch (default: 50)
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Each event contains one review:

          {
            "review_id": ...,
            "rating": 5,
            "review": "Absolutely beautiful...",
            "listing_id": ...,
            "buyer_name": "Sarah M.",
            "create_timestamp": ...
          }
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
        'min_rating' => 5,
        'limit' => 50,
        'expected_update_period_in_days' => 1
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
      reviews = fetch_reviews
      seen = memory['seen_review_ids'] ||= []
      min_rating = interpolated['min_rating'].to_i
      new_reviews = reviews.select { |r| r['rating'].to_i >= min_rating && !seen.include?(r['review_id']) }
      new_reviews.each do |review|
        create_event payload: normalize_review(review)
        seen << review['review_id']
      end
      memory['seen_review_ids'] = seen.last(500)
      save!
    end

    private

    def fetch_reviews
      response = faraday.get(
        "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/reviews",
        { limit: interpolated['limit'].to_i },
        { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}" }
      )
      raise "Etsy API error #{response.status}" unless response.success?

      JSON.parse(response.body)['results'] || []
    rescue StandardError => e
      error("ReviewScraperAgent error: #{e.message}")
      []
    end

    def normalize_review(r)
      {
        'review_id' => r['review_id'],
        'rating' => r['rating'],
        'review' => r['review'],
        'listing_id' => r['listing_id'],
        'buyer_name' => r.dig('buyer', 'login_name') || 'Verified Buyer',
        'create_timestamp' => r['create_timestamp']
      }
    end
  end
end
