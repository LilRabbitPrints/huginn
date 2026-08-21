module Agents
  class MockupGeneratorWebhookAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **MockupGeneratorWebhookAgent** receives an optimised listing brief event and sends
      a carousel spec payload to your external bulk mockup generator application via webhook POST.

      It packages the listing data into a structured `carousel_spec` JSON that tells your mockup
      app exactly which template, text overlays, product variant, and background to use for each
      of the 7 carousel image slots.

      **Options:**
      - `mockup_app_url` — Webhook URL of your mockup generator app
      - `mockup_app_secret` — Secret/auth header value for your app (sent as `X-Mockup-Secret`)
      - `product_type_map` — JSON hash mapping Etsy shop section IDs to product types
        (e.g., `{"12345": "mug", "67890": "print"}`)
      - `default_product_type` — Fallback product type (default: `print`)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits a confirmation event with `mockup_request_id`, `listing_id`, `product_type`,
      and `carousel_spec` (the spec sent to the mockup app).
    MD

    def default_options
      {
        'mockup_app_url' => '',
        'mockup_app_secret' => '',
        'product_type_map' => {},
        'default_product_type' => 'print',
        'expected_receive_period_in_days' => 2
      }
    end

    def validate_options
      errors.add(:base, 'mockup_app_url is required') if options['mockup_app_url'].blank?
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        product_type = resolve_product_type(payload)
        spec = build_carousel_spec(payload, product_type)
        request_id = send_to_mockup_app(payload['listing_id'], product_type, spec)
        next unless request_id

        create_event payload: {
          'listing_id' => payload['listing_id'],
          'mockup_request_id' => request_id,
          'product_type' => product_type,
          'carousel_spec' => spec,
          'sent_at' => Time.now.utc.iso8601
        }.merge(payload)
      end
    end

    private

    def resolve_product_type(payload)
      map = interpolated['product_type_map'] || {}
      section_id = payload['shop_section_id'].to_s
      map[section_id] || interpolated['default_product_type']
    end

    def build_carousel_spec(payload, product_type)
      {
        'listing_id' => payload['listing_id'],
        'product_type' => product_type,
        'title' => payload['optimized_title'] || payload['title'],
        'primary_keyword' => payload.dig('tags', 0),
        'slots' => [
          { 'slot' => 1, 'type' => 'hero_lifestyle', 'template' => "#{product_type}_hero", 'text_overlay' => payload['optimized_title']&.truncate(60) },
          { 'slot' => 2, 'type' => 'detail_closeup', 'template' => "#{product_type}_detail", 'text_overlay' => 'Premium Quality Print' },
          { 'slot' => 3, 'type' => 'personalisation_example', 'template' => "#{product_type}_personalised", 'text_overlay' => payload['personalization_hook']&.truncate(60) },
          { 'slot' => 4, 'type' => 'size_scale', 'template' => "#{product_type}_scale", 'text_overlay' => nil },
          { 'slot' => 5, 'type' => 'bulk_info_chart', 'template' => 'bulk_pricing_chart', 'text_overlay' => payload['bulk_order_pitch']&.truncate(80) },
          { 'slot' => 6, 'type' => 'packaging', 'template' => 'packaging_unboxing', 'text_overlay' => 'Beautifully Gift-Wrapped' },
          { 'slot' => 7, 'type' => 'social_proof', 'template' => 'review_quote', 'text_overlay' => nil }
        ]
      }
    end

    def send_to_mockup_app(listing_id, product_type, spec)
      response = faraday.post(
        interpolated['mockup_app_url'],
        { listing_id: listing_id, product_type: product_type, carousel_spec: spec }.to_json,
        {
          'Content-Type' => 'application/json',
          'X-Mockup-Secret' => interpolated['mockup_app_secret']
        }
      )
      raise "Mockup app error #{response.status}: #{response.body}" unless response.success?

      body = JSON.parse(response.body)
      body['request_id'] || SecureRandom.hex(8)
    rescue StandardError => e
      error("MockupGeneratorWebhookAgent error for listing #{listing_id}: #{e.message}")
      nil
    end
  end
end
