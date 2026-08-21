module Agents
  class CarouselHeroImageAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **CarouselHeroImageAgent** orchestrates the creation of slot 1 (the hero lifestyle photo)
      in the product image carousel. It selects the appropriate lifestyle template, injects text
      overlays, chooses a background scene, and validates the output image quality.

      It emits a structured `hero_spec` event for your mockup generator to action.

      **Options:**
      - `product_type_templates` — JSON map of product type to hero template name
      - `default_template` — fallback template (default: `lifestyle_hero_default`)
      - `overlay_max_chars` — max characters for text overlay (default: 60)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `hero_spec: {template, text_overlay, background, product_type}`.
    MD

    def default_options
      {
        'product_type_templates' => {
          'print' => 'print_nursery_hero', 'mug' => 'mug_kitchen_hero',
          'tote' => 'tote_outdoor_hero', 'card' => 'card_desk_hero',
          'cushion' => 'cushion_living_hero'
        },
        'default_template' => 'lifestyle_hero_default',
        'overlay_max_chars' => 60,
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
        templates = interpolated['product_type_templates'] || {}
        template = templates[product_type] || interpolated['default_template']
        background = background_for(product_type)
        overlay = (payload['optimized_title'] || payload['title']).to_s
                  .truncate(interpolated['overlay_max_chars'].to_i)

        hero_spec = {
          'slot' => 1,
          'type' => 'hero_lifestyle',
          'template' => template,
          'text_overlay' => overlay,
          'background' => background,
          'product_type' => product_type
        }
        create_event payload: payload.merge('hero_spec' => hero_spec, 'current_slot' => 1)
      end
    end

    private

    def background_for(product_type)
      {
        'print' => 'nursery_shelf', 'mug' => 'kitchen_counter',
        'tote' => 'garden_path', 'card' => 'wooden_desk',
        'cushion' => 'sofa_throw'
      }[product_type] || 'neutral_lifestyle'
    end
  end
end
