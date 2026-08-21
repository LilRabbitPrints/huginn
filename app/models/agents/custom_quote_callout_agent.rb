module Agents
  class CustomQuoteCalloutAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **CustomQuoteCalloutAgent** adds a "Need 50+? Message us for a custom quote" CTA banner
      to the bottom of the bulk order info chart spec (slot 5).

      It generates the CTA text, button label, and background color for the banner overlay,
      tailored to the product type and any campaign context.

      **Options:**
      - `min_qty_for_quote` — minimum quantity to show the custom quote CTA (default: 50)
      - `cta_text` — customisable CTA body text
      - `button_label` — button label text (default: `Get a Custom Quote →`)
      - `banner_color` — hex color for the banner background (default: `#2d1b0e`)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `custom_quote_banner` merged into `info_chart_spec`.
    MD

    def default_options
      {
        'min_qty_for_quote' => 50,
        'cta_text' => 'Need 50+ items? We offer fully custom bulk orders with branded packaging, custom designs, and dedicated account support.',
        'button_label' => 'Get a Custom Quote →',
        'banner_color' => '#2d1b0e',
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        banner = {
          'min_qty' => interpolated['min_qty_for_quote'].to_i,
          'text' => interpolated['cta_text'],
          'button_label' => interpolated['button_label'],
          'background_color' => interpolated['banner_color'],
          'text_color' => '#ffffff',
          'position' => 'bottom'
        }
        chart_spec = (payload['info_chart_spec'] || {}).merge('custom_quote_banner' => banner)
        create_event payload: payload.merge('info_chart_spec' => chart_spec)
      end
    end
  end
end
