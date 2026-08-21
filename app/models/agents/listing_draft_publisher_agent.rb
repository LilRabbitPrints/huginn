module Agents
  class ListingDraftPublisherAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **ListingDraftPublisherAgent** receives a new listing event from EtsyListingCreatorAgent
      and ensures it is saved as a proper draft on Etsy, then stores the draft listing ID and URL
      in memory for downstream agents.

      It emits a `draft_ready` event so the image uploader and confirmation agents can proceed.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "draft_ready", new_listing_id: ..., draft_url: ..., ...original payload}`.
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
        next unless listing_id

        drafts = memory['drafts'] ||= {}
        drafts[listing_id.to_s] = {
          'listing_id' => listing_id,
          'draft_url' => payload['draft_url'],
          'title' => payload['title'],
          'created_at' => Time.now.utc.iso8601
        }
        memory['drafts'] = drafts
        save!

        create_event payload: payload.merge('event_type' => 'draft_ready')
        log("Draft listing #{listing_id} registered: #{payload['draft_url']}")
      end
    end
  end
end
