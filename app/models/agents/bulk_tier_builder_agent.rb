module Agents
  class BulkTierBuilderAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **BulkTierBuilderAgent** calculates and formats the bulk pricing tier table for the
      info chart image (slot 5). It takes the listing's base price and applies discount percentages
      to generate a formatted pricing table with per-item prices for each tier.

      **Options:**
      - `pricing_tiers` — JSON array of tier objects `{min_qty, max_qty, discount_pct, label}`
      - `currency_symbol` — (default: `£`)
      - `show_savings` — include "You save X%" callout (default: true)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `pricing_table` (array of formatted tier rows) in `info_chart_spec`.
    MD

    def default_options
      {
        'pricing_tiers' => [
          { 'min_qty' => 5, 'max_qty' => 9, 'discount_pct' => 10, 'label' => '5–9 items' },
          { 'min_qty' => 10, 'max_qty' => 24, 'discount_pct' => 20, 'label' => '10–24 items' },
          { 'min_qty' => 25, 'max_qty' => 49, 'discount_pct' => 30, 'label' => '25–49 items' }
        ],
        'currency_symbol' => '£',
        'show_savings' => true,
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        base_price = payload['price'].to_f
        symbol = interpolated['currency_symbol']
        show_savings = boolify(interpolated['show_savings'])

        table = (interpolated['pricing_tiers'] || []).map do |tier|
          discount = tier['discount_pct'].to_f / 100.0
          discounted = (base_price * (1 - discount)).round(2)
          {
            'label' => tier['label'],
            'min_qty' => tier['min_qty'],
            'max_qty' => tier['max_qty'],
            'per_item_price' => "#{symbol}#{format('%.2f', discounted)}",
            'discount_pct' => tier['discount_pct'].to_i,
            'savings_label' => show_savings ? "Save #{tier['discount_pct'].to_i}%" : nil
          }.compact
        end

        chart_spec = (payload['info_chart_spec'] || {}).merge('pricing_table' => table, 'base_price_display' => "#{symbol}#{format('%.2f', base_price)}")
        create_event payload: payload.merge('info_chart_spec' => chart_spec, 'pricing_table' => table)
      end
    end
  end
end
