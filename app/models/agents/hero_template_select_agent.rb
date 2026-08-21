module Agents
  class HeroTemplateSelectAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **HeroTemplateSelectAgent** selects the most appropriate hero lifestyle template for
      a product based on its type, season, and any campaign flags in the event payload.

      It evaluates a priority-ordered template list and picks the best match, taking into account:
      - Product type (print, mug, tote, card, cushion, etc.)
      - Current season (spring/summer/autumn/winter)
      - Whether the listing is a personalised or bulk-order focus

      **Options:**
      - `template_library` — JSON map of `"product_type:season:focus"` to template name
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `selected_hero_template` and `template_reason` fields.
    MD

    def default_options
      {
        'template_library' => {
          'print:spring:personalised' => 'print_spring_personalised_hero',
          'print:summer:personalised' => 'print_summer_bright_hero',
          'print:autumn:personalised' => 'print_autumn_cosy_hero',
          'print:winter:personalised' => 'print_winter_festive_hero',
          'mug:any:bulk' => 'mug_bulk_corporate_hero',
          'default' => 'lifestyle_hero_default'
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
        season = current_season
        focus = payload['bulk_focus'] ? 'bulk' : 'personalised'
        lib = interpolated['template_library'] || {}

        template = lib["#{product_type}:#{season}:#{focus}"] ||
                   lib["#{product_type}:any:#{focus}"] ||
                   lib["#{product_type}:#{season}:any"] ||
                   lib['default'] ||
                   'lifestyle_hero_default'

        reason = "product=#{product_type}, season=#{season}, focus=#{focus}"
        create_event payload: payload.merge(
          'selected_hero_template' => template,
          'template_reason' => reason
        )
      end
    end

    private

    def current_season
      month = Date.today.month
      case month
      when 3..5 then 'spring'
      when 6..8 then 'summer'
      when 9..11 then 'autumn'
      else 'winter'
      end
    end
  end
end
