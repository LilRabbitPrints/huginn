module Agents
  class CurrentTagInventoryAgent < Agent
    include WebRequestConcern

    default_schedule "every_7d"

    description <<~MD
      The **CurrentTagInventoryAgent** fetches and catalogues all tags currently used across
      your active Etsy listings, building a complete tag inventory with frequency counts.

      This gives you a clear picture of which tags you're over-relying on and which listing
      sections are tag-sparse.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits a single event with the full tag inventory:

          {
            "event_type": "tag_inventory",
            "tag_frequency": {"personalised rabbit": 12, "bunny gift": 8, ...},
            "total_listings": 45,
            "listings_missing_tags": 3,
            "generated_at": "..."
          }
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
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
      listings = fetch_listings
      tag_freq = Hash.new(0)
      missing_tags_count = 0

      listings.each do |listing|
        tags = listing['tags'] || []
        missing_tags_count += 1 if tags.size < 13
        tags.each { |t| tag_freq[t.downcase] += 1 }
      end

      create_event payload: {
        'event_type' => 'tag_inventory',
        'tag_frequency' => tag_freq.sort_by { |_, v| -v }.first(100).to_h,
        'total_listings' => listings.size,
        'listings_missing_tags' => missing_tags_count,
        'avg_tags_per_listing' => listings.empty? ? 0 : (tag_freq.values.sum.to_f / listings.size).round(1),
        'generated_at' => Time.now.utc.iso8601
      }
    end

    private

    def fetch_listings
      response = faraday.get(
        "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/listings",
        { state: 'active', limit: 100 },
        { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}" }
      )
      return [] unless response.success?

      JSON.parse(response.body)['results'] || []
    rescue StandardError => e
      error("CurrentTagInventoryAgent error: #{e.message}")
      []
    end
  end
end
