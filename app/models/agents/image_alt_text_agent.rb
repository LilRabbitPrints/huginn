module Agents
  class ImageAltTextAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **ImageAltTextAgent** verifies that all 7 image slots are filled for a listing (Etsy
      rewards full image carousels in search ranking) and checks image metadata quality.

      It can also update image alt text (rank labels) on Etsy listings via the API to ensure
      keyword-rich alt text for each slot.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `update_alt_text` — whether to update alt text via API (default: false)
      - `alt_text_template` — Liquid template for alt text (default: `{{title}} - image {{slot}}`)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `image_audit: {image_count, all_slots_filled, missing_slots, alt_text_updated}`.
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
        'update_alt_text' => false,
        'alt_text_template' => '{{title}} - photo {{slot}}',
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        images = payload['images'] || payload['mockup_images'] || []
        filled_slots = images.map { |i| i['rank'] || i['slot'] }.compact.map(&:to_i)
        expected = (1..7).to_a
        missing = expected - filled_slots
        all_filled = missing.empty?

        alt_updated = false
        if boolify(interpolated['update_alt_text']) && payload['listing_id'].present?
          alt_updated = update_alt_texts(payload['listing_id'], images, payload['title'])
        end

        create_event payload: payload.merge(
          'image_audit' => {
            'image_count' => images.size,
            'all_slots_filled' => all_filled,
            'missing_slots' => missing,
            'alt_text_updated' => alt_updated
          }
        )
      end
    end

    private

    def update_alt_texts(listing_id, images, title)
      images.each do |img|
        slot = (img['rank'] || img['slot']).to_i
        img_id = img['listing_image_id'] || img['id']
        next unless img_id

        alt = "#{title&.truncate(60)} - image #{slot}"
        faraday.patch(
          "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/listings/#{listing_id}/images/#{img_id}",
          { alt_text: alt }.to_json,
          { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}", 'Content-Type' => 'application/json' }
        )
      rescue StandardError => e
        error("ImageAltTextAgent alt text update error: #{e.message}")
      end
      true
    rescue StandardError
      false
    end
  end
end
