module Agents
  class CompetitorTagAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **CompetitorTagAgent** scrapes the tags from top-ranked competitor listings in your
      product niche on Etsy to discover keyword strategies that are working for similar sellers.

      It searches Etsy for your seed keywords and extracts the tags from the top 10 results,
      identifying tags you're not currently using.

      **Options:**
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `results_to_scrape` — number of top results to examine per keyword (default: 10)
      - `exclude_shop_id` — your own shop ID to exclude from results
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits discovered competitor tags:

          {
            "keyword": "bunny nursery art uk",
            "source": "competitor_tag",
            "competitor_listing_id": 9876543,
            "seed_keyword": "bunny nursery art",
            "collected_at": "..."
          }
    MD

    def default_options
      {
        'api_key' => '',
        'access_token' => '',
        'results_to_scrape' => 10,
        'exclude_shop_id' => '',
        'expected_receive_period_in_days' => 2
      }
    end

    def validate_options
      errors.add(:base, 'api_key is required') if options['api_key'].blank?
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        seed = event.payload['seed_keyword'].to_s
        next if seed.blank?

        competitor_tags = scrape_competitor_tags(seed)
        competitor_tags.each do |listing_id, tag|
          create_event payload: {
            'keyword' => tag,
            'source' => 'competitor_tag',
            'competitor_listing_id' => listing_id,
            'seed_keyword' => seed,
            'collected_at' => Time.now.utc.iso8601
          }
        end
      end
    end

    private

    def scrape_competitor_tags(query)
      response = faraday.get(
        'https://openapi.etsy.com/v3/application/listings/active',
        { keywords: query, limit: interpolated['results_to_scrape'].to_i },
        { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}" }
      )
      return [] unless response.success?

      results = JSON.parse(response.body)['results'] || []
      exclude = interpolated['exclude_shop_id'].to_s
      tags = []
      results.each do |listing|
        next if exclude.present? && listing['shop_id'].to_s == exclude

        (listing['tags'] || []).each do |tag|
          tags << [listing['listing_id'], tag]
        end
      end
      tags
    rescue StandardError => e
      error("CompetitorTagAgent error for '#{query}': #{e.message}")
      []
    end
  end
end
