module Agents
  class ShopPeakDetectorAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **ShopPeakDetectorAgent** receives daily_shop_stats events and fires an alert when
      traffic spikes more than `spike_multiplier`× the rolling average. This tells you to
      post on social media immediately to capitalise on the surge.

      **Options:**
      - `spike_multiplier` — traffic must be this many times above average to trigger alert
        (default: 2.0)
      - `rolling_average_days` — number of days to use for baseline average (default: 7)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "traffic_spike", views_today: ..., average_views: ..., multiplier: ..., alert: "..."}`.
    MD

    def default_options
      {
        'spike_multiplier' => 2.0,
        'rolling_average_days' => 7,
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        next unless payload['event_type'] == 'daily_shop_stats'

        views = payload['total_views_today'].to_f
        history = memory['views_history'] ||= []
        history << views
        history = history.last(interpolated['rolling_average_days'].to_i)
        memory['views_history'] = history
        save!

        next unless history.size >= 3

        avg = history[0..-2].sum / [history[0..-2].size, 1].max
        multiplier = avg.positive? ? (views / avg).round(2) : 1.0

        if multiplier >= interpolated['spike_multiplier'].to_f
          create_event payload: {
            'event_type' => 'traffic_spike',
            'views_today' => views.to_i,
            'average_views' => avg.round(1),
            'multiplier' => multiplier,
            'alert' => "🚀 Traffic is #{multiplier}× your average (#{views.to_i} vs avg #{avg.round(0)}) — post on social NOW!",
            'detected_at' => Time.now.utc.iso8601
          }
          log("ShopPeakDetectorAgent: spike detected #{multiplier}× average")
        end
      end
    end
  end
end
