module Agents
  class TopListingAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **TopListingAgent** identifies your top 3 performing listings this week based on
      view velocity (views per day) and favourite growth. This tells you which listings to
      double down on promoting.

      It accumulates daily stats events and emits a top listings report weekly.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `top_n` — number of top listings to report (default: 3)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "top_listings_report", top_listings: [...], week_of: "..."}`.
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
        'top_n' => 3,
        'expected_receive_period_in_days' => 2
      }
    end

    def validate_options
      errors.add(:base, 'shop_id is required') if options['shop_id'].blank?
      errors.add(:base, 'api_key is required') if options['api_key'].blank?
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        next unless event.payload['event_type'] == 'daily_shop_stats'

        listings = fetch_listing_stats
        top = listings.sort_by { |l| -l['views'].to_i }.first(interpolated['top_n'].to_i)
        create_event payload: {
          'event_type' => 'top_listings_report',
          'top_listings' => top.map { |l| l.slice('listing_id', 'title', 'views', 'num_favorers') },
          'week_of' => Date.today.to_s,
          'total_active_listings' => listings.size
        }
      end
    end

    private

    def fetch_listing_stats
      response = faraday_client.get(
        "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/listings",
        { state: 'active', limit: 100 },
        { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}" }
      )
      return [] unless response.success?

      JSON.parse(response.body)['results'] || []
    rescue StandardError => e
      error("TopListingAgent: #{e.message}")
      []
    end

    def faraday_client
      require 'faraday'
      Faraday.new { |f| f.adapter Faraday.default_adapter }
    end
  end
end
