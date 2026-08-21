module Agents
  class EtsyListingsAgent < Agent
    include WebRequestConcern

    can_dry_run!
    default_schedule "every_1h"

    description <<~MD
      The **EtsyListingsAgent** fetches listings from your Etsy shop via the Etsy v3 API and emits each
      listing as an event for downstream revival-pipeline agents.

      **Required options:**
      - `shop_id` — Your Etsy shop ID (numeric string or shop name slug)
      - `api_key` — Your Etsy v3 API key (keystring)
      - `access_token` — Your Etsy OAuth2 access token
      - `state` — Listing state to fetch: `inactive` (default), `active`, `draft`, or `sold_out`
      - `limit` — Max listings per API call (default: 100, max: 100)
      - `emit_on_change_only` — Set to `true` to only emit listings whose data changed since last run

      Each event payload contains:
      - `listing_id`, `title`, `description`, `state`, `price`, `currency_code`
      - `tags` (array), `images` (array of image objects)
      - `views`, `num_favorers`, `creation_timestamp`, `last_modified_timestamp`
      - `quantity`, `shipping_profile_id`, `shop_section_id`
      - `has_variations`, `is_customizable`, `should_auto_renew`
    MD

    event_description <<~MD
      Events look like this:

          {
            "listing_id": 1234567890,
            "title": "Personalised Rabbit Print Gift",
            "description": "...",
            "state": "inactive",
            "price": "12.99",
            "currency_code": "GBP",
            "tags": ["rabbit print", "bunny gift"],
            "views": 340,
            "num_favorers": 28,
            "creation_timestamp": 1700000000,
            "last_modified_timestamp": 1710000000,
            "images": [{"url_fullxfull": "https://..."}]
          }
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
        'state' => 'inactive',
        'limit' => 100,
        'emit_on_change_only' => false,
        'expected_update_period_in_days' => 1
      }
    end

    def validate_options
      errors.add(:base, 'shop_id is required') if options['shop_id'].blank?
      errors.add(:base, 'api_key is required') if options['api_key'].blank?
      errors.add(:base, 'access_token is required') if options['access_token'].blank?
      errors.add(:base, 'state must be inactive, active, draft, or sold_out') unless
        %w[inactive active draft sold_out].include?(options['state'])
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def check
      fetch_listings.each do |listing|
        payload = normalize_listing(listing)
        next if boolify(interpolated['emit_on_change_only']) && !changed?(payload)

        create_event payload: payload
      end
    end

    private

    def fetch_listings
      offset = 0
      all_listings = []
      loop do
        response = faraday.get(
          "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/listings",
          { state: interpolated['state'], limit: interpolated['limit'].to_i, offset: offset },
          {
            'x-api-key' => interpolated['api_key'],
            'Authorization' => "******'access_token']}"
          }
        )
        raise "Etsy API error #{response.status}: #{response.body}" unless response.success?

        body = JSON.parse(response.body)
        results = body['results'] || []
        all_listings.concat(results)
        break if results.size < interpolated['limit'].to_i

        offset += results.size
      end
      all_listings
    rescue StandardError => e
      error("EtsyListingsAgent fetch error: #{e.message}")
      []
    end

    def normalize_listing(listing)
      {
        'listing_id' => listing['listing_id'],
        'title' => listing['title'],
        'description' => listing['description'],
        'state' => listing['state'],
        'price' => listing.dig('price', 'amount').to_f / (listing.dig('price', 'divisor') || 100).to_f,
        'currency_code' => listing.dig('price', 'currency_code'),
        'tags' => listing['tags'] || [],
        'views' => listing['views'],
        'num_favorers' => listing['num_favorers'],
        'creation_timestamp' => listing['creation_timestamp'],
        'last_modified_timestamp' => listing['last_modified_timestamp'],
        'quantity' => listing['quantity'],
        'shipping_profile_id' => listing['shipping_profile_id'],
        'shop_section_id' => listing['shop_section_id'],
        'has_variations' => listing['has_variations'],
        'is_customizable' => listing['is_customizable'],
        'should_auto_renew' => listing['should_auto_renew'],
        'images' => listing['images'] || []
      }
    end

    def changed?(payload)
      last = memory['last_seen'] ||= {}
      key = payload['listing_id'].to_s
      fingerprint = [payload['title'], payload['state'], payload['last_modified_timestamp']].join('|')
      if last[key] != fingerprint
        last[key] = fingerprint
        save!
        true
      else
        false
      end
    end
  end
end
