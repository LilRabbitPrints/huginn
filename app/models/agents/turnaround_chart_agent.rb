module Agents
  class TurnaroundChartAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **TurnaroundChartAgent** adds production and shipping timeline rows to the bulk
      order info chart. It maps order quantity ranges to expected production time + shipping
      window and formats them for inclusion in the infographic.

      **Options:**
      - `turnaround_rules` — JSON array of `{min_qty, max_qty, production_days, shipping_days, label}`
      - `rush_available` — whether to show a "Rush Order Available" note (default: false)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `turnaround_table` merged into `info_chart_spec`.
    MD

    def default_options
      {
        'turnaround_rules' => [
          { 'min_qty' => 1, 'max_qty' => 4, 'production_days' => '1-2', 'shipping_days' => '2-4', 'label' => '1–4 items' },
          { 'min_qty' => 5, 'max_qty' => 9, 'production_days' => '2-3', 'shipping_days' => '2-4', 'label' => '5–9 items' },
          { 'min_qty' => 10, 'max_qty' => 24, 'production_days' => '4-5', 'shipping_days' => '2-4', 'label' => '10–24 items' },
          { 'min_qty' => 25, 'max_qty' => nil, 'production_days' => '5-7', 'shipping_days' => '3-5', 'label' => '25+ items' }
        ],
        'rush_available' => false,
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        turnaround_table = (interpolated['turnaround_rules'] || []).map do |rule|
          {
            'label' => rule['label'],
            'production' => "#{rule['production_days']} working days",
            'shipping' => "#{rule['shipping_days']} days (UK tracked)",
            'total_estimate' => "#{add_ranges(rule['production_days'], rule['shipping_days'])} days total"
          }
        end

        rush_note = boolify(interpolated['rush_available']) ? '⚡ Rush orders available — message us!' : nil
        chart_spec = (payload['info_chart_spec'] || {}).merge(
          'turnaround_table' => turnaround_table,
          'rush_note' => rush_note
        ).compact
        create_event payload: payload.merge('info_chart_spec' => chart_spec)
      end
    end

    private

    def add_ranges(range1, range2)
      min1, max1 = range1.to_s.split('-').map(&:to_i)
      min2, max2 = range2.to_s.split('-').map(&:to_i)
      "#{min1 + min2}–#{max1 + max2}"
    end
  end
end
