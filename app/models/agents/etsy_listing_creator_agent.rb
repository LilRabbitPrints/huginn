module Agents
  class EtsyListingCreatorAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **EtsyListingCreatorAgent** creates a new, fresh Etsy listing via the Etsy v3 API
      using the optimised brief and mockup images produced by the revival pipeline.

      It always creates the listing in `draft` state first so you can review before publishing.
      After creation it emits an event containing the new `listing_id`, draft URL, and all
      field values used.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `default_quantity` — Default listing quantity (default: 999)
      - `default_who_made` — `i_did`, `collective`, or `someone_else` (default: `i_did`)
      - `default_when_made` — e.g., `made_to_order` (default)
      - `default_taxonomy_id` — Etsy taxonomy ID for your product category
      - `shipping_profile_id` — Your Etsy shipping profile ID
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits a payload with the new listing details:

          {
            "new_listing_id": 9876543210,
            "draft_url": "https://www.etsy.com/...",
            "title": "...",
            "tags": [...],
            "state": "draft",
            "original_listing_id": 1234567890
          }
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
        'default_quantity' => 999,
        'default_who_made' => 'i_did',
        'default_when_made' => 'made_to_order',
        'default_taxonomy_id' => '',
        'shipping_profile_id' => '',
        'expected_receive_period_in_days' => 2
      }
    end

    def validate_options
      %w[shop_id api_key access_token].each do |k|
        errors.add(:base, "#{k} is required") if options[k].blank?
      end
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        new_listing = create_listing(payload)
        next unless new_listing

        create_event payload: {
          'new_listing_id' => new_listing['listing_id'],
          'draft_url' => "https://www.etsy.com/listing/#{new_listing['listing_id']}",
          'title' => new_listing['title'],
          'tags' => new_listing['tags'],
          'state' => new_listing['state'],
          'original_listing_id' => payload['listing_id'],
          'brief_payload' => payload
        }
      end
    end

    private

    def create_listing(payload)
      body = {
        quantity: interpolated['default_quantity'].to_i,
        title: payload['optimized_title'] || payload['title'],
        description: [payload['short_description'], payload['long_description']].compact.join("\n\n"),
        price: payload['price'].to_f,
        who_made: interpolated['default_who_made'],
        when_made: interpolated['default_when_made'],
        taxonomy_id: interpolated['default_taxonomy_id'].to_i,
        shipping_profile_id: interpolated['shipping_profile_id'].to_i,
        tags: payload['tags'] || [],
        state: 'draft',
        is_customizable: true,
        should_auto_renew: true
      }.reject { |_, v| v.blank? || v.zero? }

      response = faraday.post(
        "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/listings",
        body.to_json,
        {
          'x-api-key' => interpolated['api_key'],
          'Authorization' => "******'access_token']}",
          'Content-Type' => 'application/json'
        }
      )
      raise "Etsy create listing error #{response.status}: #{response.body}" unless response.success?

      JSON.parse(response.body)
    rescue StandardError => e
      error("EtsyListingCreatorAgent error: #{e.message}")
      nil
    end
  end
end
