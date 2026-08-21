module Agents
  class FlashSaleSchedulerAgent < Agent
    include WebRequestConcern

    default_schedule "0 9 * * 1,3,5"

    description <<~MD
      The **FlashSaleSchedulerAgent** runs on a configurable schedule (default: Mon/Wed/Fri at 9am)
      and triggers the daily sales promotion pipeline. It selects 1–3 active listings to spotlight,
      rotating through your catalogue to ensure full exposure.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `listings_per_run` — how many listings to promote each run (default: 1)
      - `rotation_strategy` — `least_recently_promoted`, `highest_views`, `random` (default: least_recently_promoted)
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits one promotion trigger event per selected listing:

          {
            "event_type": "promotion_trigger",
            "listing_id": ...,
            "title": "...",
            "price": ...,
            "tags": [...],
            "listing_url": "https://www.etsy.com/listing/...",
            "triggered_at": "..."
          }
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
        'listings_per_run' => 1,
        'rotation_strategy' => 'least_recently_promoted',
        'expected_update_period_in_days' => 3
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
      listings = fetch_active_listings
      selected = select_listings(listings)
      selected.each do |listing|
        record_promotion(listing['listing_id'].to_s)
        create_event payload: {
          'event_type' => 'promotion_trigger',
          'listing_id' => listing['listing_id'],
          'title' => listing['title'],
          'description' => listing['description']&.truncate(300),
          'price' => listing.dig('price', 'amount').to_f / 100.0,
          'currency_code' => listing.dig('price', 'currency_code'),
          'tags' => listing['tags'] || [],
          'listing_url' => "https://www.etsy.com/listing/#{listing['listing_id']}",
          'images' => listing['images'] || [],
          'triggered_at' => Time.now.utc.iso8601
        }
      end
      log("FlashSaleSchedulerAgent triggered #{selected.size} promotions")
    end

    private

    def select_listings(listings)
      promoted = memory['promoted'] ||= {}
      n = interpolated['listings_per_run'].to_i
      case interpolated['rotation_strategy']
      when 'least_recently_promoted'
        listings.sort_by { |l| promoted[l['listing_id'].to_s].to_i }.first(n)
      when 'highest_views'
        listings.sort_by { |l| -l['views'].to_i }.first(n)
      else
        listings.sample(n)
      end
    end

    def record_promotion(listing_id)
      promoted = memory['promoted'] ||= {}
      promoted[listing_id] = Time.now.to_i
      memory['promoted'] = promoted
      save!
    end

    def fetch_active_listings
      response = faraday.get(
        "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/listings",
        { state: 'active', limit: 100, includes: 'Images' },
        { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}" }
      )
      return [] unless response.success?

      JSON.parse(response.body)['results'] || []
    rescue StandardError => e
      error("FlashSaleSchedulerAgent: #{e.message}")
      []
    end
  end
end
