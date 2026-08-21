module Agents
  class CarouselSpecBuilderAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **CarouselSpecBuilderAgent** assembles the 7-slot image carousel specification JSON
      from a listing brief event. It enriches the slot specs with background scene selection,
      template name resolution, and text overlay generation for each slot.

      This agent is a sub-agent of MockupGeneratorWebhookAgent and runs before the webhook is
      fired to produce a complete, validated `carousel_spec`.

      **Slot assignments:**
      1. Hero lifestyle photo (stop-scroll image)
      2. Close-up quality/material shot
      3. Personalisation example
      4. Size/scale reference
      5. Bulk order pricing infographic
      6. Packaging/unboxing photo
      7. Social proof (review quote)

      **Options:**
      - `background_map` — JSON mapping product categories to background scenes
      - `default_background` — fallback scene (default: `nursery`)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with a complete `carousel_spec` object containing all 7 slot definitions.
    MD

    def default_options
      {
        'background_map' => {
          'print' => 'nursery', 'mug' => 'kitchen', 'tote' => 'outdoor',
          'cushion' => 'living_room', 'card' => 'desk'
        },
        'default_background' => 'nursery',
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        spec = build_spec(event.payload)
        create_event payload: event.payload.merge('carousel_spec' => spec)
      end
    end

    private

    def build_spec(payload)
      product_type = payload['product_type'] || 'print'
      bg_map = interpolated['background_map'] || {}
      background = bg_map[product_type] || interpolated['default_background']
      title = payload['optimized_title'] || payload['title']
      hook = payload['personalization_hook']&.truncate(60)
      bulk = payload['bulk_order_pitch']&.truncate(80)

      {
        'listing_id' => payload['listing_id'],
        'product_type' => product_type,
        'background_scene' => background,
        'slots' => [
          slot(1, 'hero_lifestyle', "#{product_type}_hero_#{background}", title&.truncate(60), background),
          slot(2, 'detail_closeup', "#{product_type}_detail", 'Premium Quality · Fade-Resistant Ink', nil),
          slot(3, 'personalisation_example', "#{product_type}_personalised", hook, nil),
          slot(4, 'size_scale', "#{product_type}_scale", nil, background),
          slot(5, 'bulk_info_chart', 'bulk_pricing_chart', bulk, nil),
          slot(6, 'packaging', 'packaging_unboxing', 'Gift-Wrapped with Care 🐇', nil),
          slot(7, 'social_proof', 'review_quote', nil, nil)
        ]
      }
    end

    def slot(number, type, template, text_overlay, background)
      {
        'slot' => number,
        'type' => type,
        'template' => template,
        'text_overlay' => text_overlay,
        'background' => background
      }.compact
    end
  end
end
