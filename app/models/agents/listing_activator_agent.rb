module Agents
  class ListingActivatorAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **ListingActivatorAgent** activates a draft Etsy listing (changes its state to `active`)
      after receiving an approval trigger event.

      Approval can come from:
      1. An email reply parsed by a WebhookAgent (set `approval_field` to the payload key, e.g. `"approved"`)
      2. A manual event with `{"action": "approve", "listing_id": 123}` sent directly
      3. Automatic activation if `auto_approve` is set to `true`

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `approval_field` — Payload key whose truthy value triggers activation (default: `approved`)
      - `auto_approve` — Activate automatically without waiting for approval field (default: false)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "listing_activated", listing_id: ..., listing_url: ..., ...}`.
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
        'approval_field' => 'approved',
        'auto_approve' => false,
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
        listing_id = payload['new_listing_id'] || payload['listing_id']
        next unless listing_id

        approved = boolify(interpolated['auto_approve']) ||
                   boolify(payload[interpolated['approval_field']]) ||
                   payload['action'] == 'approve'
        next unless approved

        activated = activate_listing(listing_id)
        next unless activated

        create_event payload: payload.merge(
          'event_type' => 'listing_activated',
          'listing_id' => listing_id,
          'listing_url' => "https://www.etsy.com/listing/#{listing_id}",
          'activated_at' => Time.now.utc.iso8601
        )
      end
    end

    private

    def activate_listing(listing_id)
      response = faraday.patch(
        "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/listings/#{listing_id}",
        { state: 'active' }.to_json,
        {
          'x-api-key' => interpolated['api_key'],
          'Authorization' => "******'access_token']}",
          'Content-Type' => 'application/json'
        }
      )
      if response.success?
        log("Activated listing #{listing_id}")
        true
      else
        error("Failed to activate listing #{listing_id}: #{response.status} #{response.body}")
        false
      end
    rescue StandardError => e
      error("ListingActivatorAgent error: #{e.message}")
      false
    end
  end
end
