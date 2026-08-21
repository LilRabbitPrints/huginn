module Agents
  class ChartDesignAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **ChartDesignAgent** applies brand styling to the info chart spec — colors, fonts,
      logo placement, and layout grid — producing a render-ready design spec for your mockup
      generator.

      It injects the Lil Rabbit Prints brand identity into the chart template:
      - Brand colors (orange `#e75b2e`, cream `#f9f0e8`, dark `#2d1b0e`)
      - Brand font pairing
      - Rabbit logo position
      - Layout variant (vertical tiers or horizontal grid)

      **Options:**
      - `font_heading` — heading font name (default: `Playfair Display`)
      - `font_body` — body font name (default: `Lato`)
      - `logo_position` — `top_left`, `top_right`, `bottom_centre` (default: `top_right`)
      - `layout_variant` — `vertical_tiers` or `horizontal_grid` (default: `vertical_tiers`)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `chart_design` spec merged into `info_chart_spec`.
    MD

    def default_options
      {
        'font_heading' => 'Playfair Display',
        'font_body' => 'Lato',
        'logo_position' => 'top_right',
        'layout_variant' => 'vertical_tiers',
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        chart_design = {
          'colors' => {
            'primary' => '#e75b2e',
            'secondary' => '#f9f0e8',
            'dark' => '#2d1b0e',
            'highlight' => '#ffd700'
          },
          'fonts' => {
            'heading' => interpolated['font_heading'],
            'body' => interpolated['font_body']
          },
          'logo_position' => interpolated['logo_position'],
          'layout_variant' => interpolated['layout_variant'],
          'border_radius' => 12,
          'shadow' => true,
          'padding' => 40
        }
        chart_spec = (payload['info_chart_spec'] || {}).merge('chart_design' => chart_design)
        create_event payload: payload.merge('info_chart_spec' => chart_spec)
      end
    end
  end
end
