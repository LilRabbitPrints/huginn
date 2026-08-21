module Agents
  class RevenueGoalAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **RevenueGoalAgent** tracks weekly revenue vs your goal and reports progress every
      Monday morning. It emits revenue goal update events and alerts when you're behind pace
      or when you've hit your target.

      **Options:**
      - `weekly_goal` — weekly revenue target in GBP (default: 500)
      - `alert_behind_pct` — emit a "behind pace" alert when below this % of goal by Wednesday (default: 30)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "revenue_goal_update", week_revenue: ..., goal: ..., pct_to_goal: ..., status: ...}`.
    MD

    def default_options
      {
        'weekly_goal' => 500,
        'alert_behind_pct' => 30,
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

        week_revenue = payload['week_revenue'].to_f
        goal = interpolated['weekly_goal'].to_f
        pct = goal.positive? ? (week_revenue / goal * 100).round(1) : 0
        day_of_week = Date.today.wday
        behind_threshold = interpolated['alert_behind_pct'].to_f

        status = if pct >= 100
                   'goal_achieved'
                 elsif day_of_week >= 3 && pct < behind_threshold
                   'behind_pace'
                 else
                   'on_track'
                 end

        create_event payload: {
          'event_type' => 'revenue_goal_update',
          'week_revenue' => week_revenue,
          'goal' => goal,
          'pct_to_goal' => pct,
          'status' => status,
          'alert' => status == 'behind_pace' ? "⚠️ You're at #{pct}% of your £#{goal.to_i} weekly goal by #{Date.today.strftime('%A')} — consider a flash sale today!" : nil,
          'updated_at' => Time.now.utc.iso8601
        }.compact
      end
    end
  end
end
