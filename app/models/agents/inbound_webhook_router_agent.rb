module Agents
  class InboundWebhookRouterAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **InboundWebhookRouterAgent** receives webhook events from WebhookRegistryAgent and
      routes them to the appropriate pipeline based on the `event_type` field. It applies
      transformation rules to normalise payloads from different external apps into a consistent
      internal format.

      **Options:**
      - `event_type_field` — the field in the payload containing the event type (default: `event_type`)
      - `normalisation_map` — JSON map of external event_type values to internal event_type values
        (e.g., `{"job_done": "mockup_job_complete", "inquiry": "bulk_inquiry_detected"}`)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Re-emits the payload with a normalised `event_type` field.
    MD

    def default_options
      {
        'event_type_field' => 'event_type',
        'normalisation_map' => {
          'job_done' => 'mockup_job_complete',
          'job_complete' => 'mockup_job_complete',
          'done' => 'mockup_job_complete',
          'inquiry' => 'bulk_inquiry_detected',
          'approved' => 'listing_approved'
        },
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload.dup
        field = interpolated['event_type_field']
        raw_type = payload[field].to_s
        norm_map = interpolated['normalisation_map'] || {}
        normalised_type = norm_map[raw_type] || raw_type

        payload[field] = normalised_type
        payload['original_event_type'] = raw_type if raw_type != normalised_type
        create_event payload: payload
      end
    end
  end
end
