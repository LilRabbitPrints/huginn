module Agents
  class DetailPersonalizationAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **DetailPersonalizationAgent** adds a personalisation zone callout to the detail image
      (slot 2). It generates an arrow/annotation overlay that highlights the customisable area
      of the product with a short instructional label.

      **Options:**
      - `callout_style` — `arrow`, `circle`, or `highlight` (default: `arrow`)
      - `callout_color` — hex color for the callout (default: `#e75b2e` — Lil Rabbit Prints orange)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `personalisation_callout` spec merged into `detail_spec`.
    MD

    PERSONALISATION_ZONES = {
      'print' => 'bottom_text_band',
      'mug' => 'front_centre',
      'tote' => 'front_panel_centre',
      'card' => 'front_top_third',
      'cushion' => 'centre_panel'
    }.freeze

    def default_options
      {
        'callout_style' => 'arrow',
        'callout_color' => '#e75b2e',
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
        zone = PERSONALISATION_ZONES[product_type] || 'centre'
        callout = {
          'zone' => zone,
          'style' => interpolated['callout_style'],
          'color' => interpolated['callout_color'],
          'label' => 'Add Your Name Here ✏️',
          'instruction' => payload['personalization_hook']&.truncate(40) || 'Personalise at checkout'
        }
        detail_spec = (payload['detail_spec'] || {}).merge('personalisation_callout' => callout)
        create_event payload: payload.merge('detail_spec' => detail_spec)
      end
    end
  end
end
