module Agents
  class MockupRequestTrackerAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **MockupRequestTrackerAgent** tracks which listings have pending mockup requests to
      prevent duplicate submissions to the mockup generator app.

      It receives events from MockupGeneratorWebhookAgent (outbound requests) and
      MockupResponseReceiverAgent (completed responses), maintaining a state map of:
      `listing_id → { status: pending|complete|failed, requested_at, completed_at }`

      Events with a `listing_id` already in `pending` state are dropped and logged.
      Events with `mockup_images` in the payload are treated as completions.

      **Options:**
      - `pending_timeout_minutes` — minutes after which a pending request is considered stale
        and can be re-submitted (default: 60)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Re-emits the original event unchanged if it is allowed through (not a duplicate).
      Adds `mockup_status` field indicating `pending`, `complete`, or `allowed`.
    MD

    def default_options
      {
        'pending_timeout_minutes' => 60,
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        listing_id = payload['listing_id'].to_s

        if payload['mockup_images'].present?
          mark_complete(listing_id)
          create_event payload: payload.merge('mockup_status' => 'complete')
          next
        end

        if pending_and_not_stale?(listing_id)
          log("MockupRequestTrackerAgent: skipping duplicate request for listing #{listing_id}")
          next
        end

        mark_pending(listing_id)
        create_event payload: payload.merge('mockup_status' => 'pending')
      end
    end

    private

    def tracker
      memory['tracker'] ||= {}
    end

    def pending_and_not_stale?(listing_id)
      entry = tracker[listing_id]
      return false unless entry&.dig('status') == 'pending'

      age_minutes = (Time.now.to_i - entry['requested_at'].to_i) / 60.0
      age_minutes < interpolated['pending_timeout_minutes'].to_f
    end

    def mark_pending(listing_id)
      tracker[listing_id] = { 'status' => 'pending', 'requested_at' => Time.now.to_i }
      memory['tracker'] = tracker
      save!
    end

    def mark_complete(listing_id)
      tracker[listing_id] = {
        'status' => 'complete',
        'requested_at' => tracker.dig(listing_id, 'requested_at'),
        'completed_at' => Time.now.to_i
      }
      memory['tracker'] = tracker
      save!
    end
  end
end
