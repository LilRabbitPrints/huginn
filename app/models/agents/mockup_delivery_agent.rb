module Agents
  class MockupDeliveryAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **MockupDeliveryAgent** receives completed mockup job events (from MockupStatusPollerAgent
      or MockupResponseReceiverAgent) and routes them to the correct listing creation pipeline
      agent by matching the `listing_id` to the pending listing's brief payload stored in memory.

      It enriches the mockup image payload with the original listing brief data (title, tags,
      description, etc.) so the downstream ListingImageUploaderAgent has everything it needs.

      **Options:**
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits the complete listing payload with `mockup_images` array ready for upload.
    MD

    def default_options
      {
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      briefs = memory['listing_briefs'] ||= {}

      incoming_events.each do |event|
        payload = event.payload
        listing_id = payload['listing_id'].to_s

        if payload['event_type'] == 'mockup_job_complete'
          brief = briefs[listing_id] || {}
          create_event payload: brief.merge(payload).merge(
            'event_type' => 'mockup_delivery_ready',
            'delivered_at' => Time.now.utc.iso8601
          )
          briefs.delete(listing_id)
          log("MockupDeliveryAgent: delivered mockup for listing #{listing_id}")
        elsif payload['optimized_title'].present? || payload['tags'].present?
          briefs[listing_id] = payload
          log("MockupDeliveryAgent: stored brief for listing #{listing_id}")
        end
      end

      memory['listing_briefs'] = briefs
      save!
    end
  end
end
