module Agents
  class ListingStateManagerAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **ListingStateManagerAgent** is the central state machine for every listing in the
      revival pipeline. It tracks each listing's journey through these states:

      `deactivated` → `in_review` → `brief_ready` → `mockups_done` → `draft` → `live`

      It listens for events from all pipeline agents and advances listing state accordingly.
      It exposes the current state map as memory for reporting agents to query.

      **Options:**
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "state_transition", listing_id: ..., from_state: ..., to_state: ..., at: ...}`.
    MD

    STATE_MACHINE = {
      'deactivated' => 'in_review',
      'in_review' => 'brief_ready',
      'brief_ready' => 'mockups_done',
      'mockups_done' => 'draft',
      'draft' => 'live'
    }.freeze

    EVENT_TO_STATE = {
      'keyword_research_trigger' => nil,
      'promotion_trigger' => nil,
      'draft_ready' => 'draft',
      'images_uploaded' => 'mockups_done',
      'listing_activated' => 'live',
      'mockup_job_complete' => 'mockups_done',
      'mockup_delivery_ready' => 'mockups_done'
    }.freeze

    def default_options
      { 'expected_receive_period_in_days' => 2 }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      state_map = memory['state_map'] ||= {}
      incoming_events.each do |event|
        payload = event.payload
        listing_id = payload['listing_id'].to_s
        next if listing_id.blank?

        event_type = payload['event_type'].to_s
        target_state = EVENT_TO_STATE[event_type]

        current = state_map[listing_id]&.dig('state') || 'deactivated'
        new_state = target_state || STATE_MACHINE[current] || current

        next if new_state == current

        state_map[listing_id] = {
          'state' => new_state,
          'listing_id' => listing_id,
          'updated_at' => Time.now.utc.iso8601
        }
        create_event payload: {
          'event_type' => 'state_transition',
          'listing_id' => listing_id,
          'from_state' => current,
          'to_state' => new_state,
          'triggered_by' => event_type,
          'at' => Time.now.utc.iso8601
        }
        log("ListingStateManagerAgent: #{listing_id} #{current} → #{new_state}")
      end
      memory['state_map'] = state_map
      save!
    end
  end
end
