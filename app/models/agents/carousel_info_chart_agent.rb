module Agents
  class CarouselInfoChartAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **CarouselInfoChartAgent** orchestrates the creation of slot 5 — the bulk order pricing
      infographic. It assembles the complete chart spec including tier pricing, turnaround times,
      and a custom-quote CTA, then emits it for your mockup generator.

      **Options:**
      - `pricing_tiers` — JSON array of `{min_qty, max_qty, discount_pct}` objects
      - `brand_color_primary` — hex color (default: `#e75b2e`)
      - `brand_color_secondary` — hex color (default: `#f9f0e8`)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `info_chart_spec` containing all chart data for slot 5.
    MD

    def default_options
      {
        'pricing_tiers' => [
          { 'min_qty' => 1, 'max_qty' => 4, 'discount_pct' => 0, 'label' => '1–4 items' },
          { 'min_qty' => 5, 'max_qty' => 9, 'discount_pct' => 10, 'label' => '5–9 items' },
          { 'min_qty' => 10, 'max_qty' => 24, 'discount_pct' => 20, 'label' => '10–24 items' },
          { 'min_qty' => 25, 'max_qty' => 49, 'discount_pct' => 30, 'label' => '25–49 items' }
        ],
        'brand_color_primary' => '#e75b2e',
        'brand_color_secondary' => '#f9f0e8',
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        info_chart_spec = {
          'slot' => 5,
          'type' => 'bulk_info_chart',
          'template' => 'bulk_pricing_chart',
          'pricing_tiers' => interpolated['pricing_tiers'],
          'product_type' => payload['product_type'] || 'print',
          'base_price' => payload['price'].to_f,
          'brand_color_primary' => interpolated['brand_color_primary'],
          'brand_color_secondary' => interpolated['brand_color_secondary'],
          'title' => 'Bulk Order Discounts',
          'subtitle' => 'Perfect for corporate gifts, hen parties & school events'
        }
        create_event payload: payload.merge('info_chart_spec' => info_chart_spec, 'current_slot' => 5)
      end
    end
  end
end
