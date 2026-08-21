module Agents
  class ListingImageUploaderAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **ListingImageUploaderAgent** uploads each carousel image to the Etsy listing via the
      Etsy v3 image API in the correct slot order (rank 1–7).

      It receives events containing `new_listing_id` and `mockup_images` (array of 7 image objects
      with `slot` and `url` fields). Images are downloaded from the URL and uploaded to Etsy
      in sequence to preserve carousel order.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "images_uploaded", new_listing_id: ..., uploaded_count: 7, ...}`.
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
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
        listing_id = payload['new_listing_id']
        images = payload['mockup_images'] || []
        next unless listing_id && images.any?

        uploaded = upload_images(listing_id, images)
        create_event payload: payload.merge(
          'event_type' => 'images_uploaded',
          'uploaded_count' => uploaded,
          'images_ready' => uploaded == images.size
        )
      end
    end

    private

    def upload_images(listing_id, images)
      count = 0
      images.sort_by { |i| i['slot'].to_i }.each do |image|
        img_data = download_image(image['url'])
        next unless img_data

        response = faraday.post(
          "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/listings/#{listing_id}/images",
          {
            rank: image['slot'].to_i,
            image: Base64.strict_encode64(img_data),
            overwrite: true
          }.to_json,
          {
            'x-api-key' => interpolated['api_key'],
            'Authorization' => "******'access_token']}",
            'Content-Type' => 'application/json'
          }
        )
        if response.success?
          count += 1
          log("Uploaded slot #{image['slot']} for listing #{listing_id}")
        else
          error("Failed to upload slot #{image['slot']} for listing #{listing_id}: #{response.status}")
        end
      end
      count
    end

    def download_image(url)
      response = faraday.get(url)
      response.success? ? response.body : nil
    rescue StandardError => e
      error("Image download failed (#{url}): #{e.message}")
      nil
    end
  end
end
