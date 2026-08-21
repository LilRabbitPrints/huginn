module Agents
  class CarouselDetailImageAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **CarouselDetailImageAgent** orchestrates slot 2 of the image carousel: the close-up
      quality and material detail shot. It determines the crop zone, badge text, and personalisation
      callout overlays for the detail image spec.

      **Options:**
      - `badge_presets` — JSON map of product type to badge text array
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `detail_spec: {slot, type, template, crop_region, badges, personalisation_callout}`.
    MD

    def default_options
      {
        'badge_presets' => {
          'print' => ['Premium Giclée Print', 'Fade-Resistant Inks', 'FSC Paper'],
          'mug' => ['Dishwasher Safe', 'Wraparound Print', '11oz/15oz Options'],
          'tote' => ['100% Cotton Canvas', 'Durable Stitching', 'Eco-Friendly'],
          'card' => ['300gsm Card', 'Satin Finish', 'Blank Inside']
        },
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        product_type = payload['product_type'] || 'print'
        badges = (interpolated['badge_presets'] || {})[product_type] || ['Premium Quality', 'Made with Care']

        detail_spec = {
          'slot' => 2,
          'type' => 'detail_closeup',
          'template' => "#{product_type}_detail_closeup",
          'crop_region' => 'center',
          'badges' => badges,
          'personalisation_callout' => payload['personalization_hook']&.truncate(50)
        }
        create_event payload: payload.merge('detail_spec' => detail_spec, 'current_slot' => 2)
      end
    end
  end
end
