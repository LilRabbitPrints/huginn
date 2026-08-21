module Agents
  class DetailTextAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **DetailTextAgent** generates callout badge text for the product detail image (slot 2).
      Badges highlight quality signals relevant to the product type to reassure buyers about
      material quality, durability, and print standards.

      **Options:**
      - `badge_style` — visual style hint for the mockup generator: `pill`, `stamp`, `ribbon`
        (default: `pill`)
      - `max_badges` — maximum number of badges to include (default: 3)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `detail_badges` (array) and `badge_style` merged into `detail_spec`.
    MD

    QUALITY_BADGES = {
      'print' => ['Premium Giclée', 'Fade-Resistant Inks', 'Recycled FSC Paper', 'Archival Quality'],
      'mug' => ['Dishwasher Safe', 'Microwave Safe', 'Wraparound Print', 'Chip-Resistant'],
      'tote' => ['100% Cotton Canvas', 'Reinforced Handles', 'Eco-Friendly', 'Machine Washable'],
      'card' => ['300gsm Luxury Card', 'Satin Finish', 'Blank Inside', 'C6 Envelope Included'],
      'cushion' => ['Hidden Zip', 'Vibrant Print', 'Feather-Feel Filling', 'Spot Clean']
    }.freeze

    def default_options
      {
        'badge_style' => 'pill',
        'max_badges' => 3,
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
        all_badges = QUALITY_BADGES[product_type] || ['Premium Quality', 'Made with Care', 'Personalised']
        badges = all_badges.first(interpolated['max_badges'].to_i)
        detail_spec = (payload['detail_spec'] || {}).merge(
          'badges' => badges,
          'badge_style' => interpolated['badge_style']
        )
        create_event payload: payload.merge('detail_spec' => detail_spec, 'detail_badges' => badges)
      end
    end
  end
end
