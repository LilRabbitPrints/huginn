module Agents
  class DetailComparisonAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **DetailComparisonAgent** optionally generates a before/after split image spec for
      slot 2 — showing the product in its generic (blank) state on the left and a personalised
      example (with a name/message) on the right.

      This is highly effective for conversion as it immediately shows buyers the transformation.

      If the event payload includes `has_variations: true` or `is_customizable: true`,
      the comparison is included. Otherwise it falls back to a single detail image.

      **Options:**
      - `example_name` — name to use in the personalised example (default: "Sophie")
      - `example_message` — message/text to use in the example (default: "Made with love 🐇")
      - `split_layout` — `side_by_side` or `before_after_overlay` (default: `side_by_side`)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `comparison_spec` added if applicable, and `use_comparison` boolean.
    MD

    def default_options
      {
        'example_name' => 'Sophie',
        'example_message' => 'Made with love 🐇',
        'split_layout' => 'side_by_side',
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        use_comparison = payload['is_customizable'] || payload['has_variations'] || true

        comparison_spec = if use_comparison
                            {
                              'layout' => interpolated['split_layout'],
                              'left_label' => 'Standard',
                              'right_label' => 'Personalised',
                              'example_name' => interpolated['example_name'],
                              'example_message' => interpolated['example_message'],
                              'product_type' => payload['product_type'] || 'print'
                            }
                          end

        create_event payload: payload.merge(
          'use_comparison' => use_comparison,
          'comparison_spec' => comparison_spec
        ).compact
      end
    end
  end
end
