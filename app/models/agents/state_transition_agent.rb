module Agents
  class StateTransitionAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **StateTransitionAgent** receives state_transition events from ListingStateManagerAgent
      and acts as a dispatcher — emitting specialised downstream trigger events for each
      state transition so the correct pipeline agents are activated.

      For example:
      - `in_review` → triggers OpenAiListingBriefAgent
      - `brief_ready` → triggers MockupGeneratorWebhookAgent
      - `mockups_done` → triggers EtsyListingCreatorAgent
      - `draft` → triggers ListingConfirmationAgent

      **Options:**
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "pipeline_trigger_<state>", listing_id: ..., ...}` per transition.
    MD

    def default_options
      { 'expected_receive_period_in_days' => 2 }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        next unless payload['event_type'] == 'state_transition'

        trigger_type = "pipeline_trigger_#{payload['to_state']}"
        create_event payload: payload.merge('event_type' => trigger_type)
        log("StateTransitionAgent: emitted #{trigger_type} for listing #{payload['listing_id']}")
      end
    end
  end
end
