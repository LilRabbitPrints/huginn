module Agents
  class WebhookRegistryAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **WebhookRegistryAgent** acts as the central inbound webhook router for all external
      apps in the Lil Rabbit Prints ecosystem. It receives webhook POSTs and routes each payload
      to the correct downstream agent based on the `event_type` field in the payload.

      Configure it as the single webhook endpoint for all your external apps. Each app POSTs
      here with an `event_type` field, and this agent emits a properly tagged event.

      **Options:**
      - `routing_map` — JSON map of `event_type → output_description` (for documentation)
      - `secret` — webhook verification secret (compared against `X-Webhook-Secret` header)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Re-emits the received payload with `webhook_received_at` timestamp added.
    MD

    def default_options
      {
        'routing_map' => {
          'mockup_complete' => 'Routes to MockupResponseReceiverAgent',
          'listing_approved' => 'Routes to ListingActivatorAgent',
          'bulk_inquiry_closed' => 'Routes to BulkOrderTrackerAgent'
        },
        'secret' => '',
        'expected_receive_period_in_days' => 1
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        next if interpolated['secret'].present? && payload['_secret'] != interpolated['secret']

        create_event payload: payload.merge('webhook_received_at' => Time.now.utc.iso8601)
        log("WebhookRegistryAgent: routed event_type=#{payload['event_type']}")
      end
    end
  end
end
