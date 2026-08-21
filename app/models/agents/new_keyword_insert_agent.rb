module Agents
  class NewKeywordInsertAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **NewKeywordInsertAgent** suggests 3 new exact-match keywords to target this week
      based on the latest consolidated keyword intelligence. It picks keywords you're not
      currently using that have the highest opportunity score.

      **Options:**
      - `suggest_n` — number of keywords to suggest (default: 3)
      - `min_score` — minimum score threshold (default: 5.0)
      - `prefer_long_tail` — prefer keywords with 3+ words (default: true)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "new_keyword_targets", keywords: [...], week_of: "..."}`.
    MD

    def default_options
      {
        'suggest_n' => 3,
        'min_score' => 5.0,
        'prefer_long_tail' => true,
        'expected_receive_period_in_days' => 8
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        next unless payload['event_type'] == 'consolidated_keywords'

        keywords = payload['keyword_list'] || []
        keywords = keywords.select { |k| k['score'].to_f >= interpolated['min_score'].to_f }
        keywords = keywords.select { |k| k['keyword'].split.size >= 3 } if boolify(interpolated['prefer_long_tail'])
        top = keywords.first(interpolated['suggest_n'].to_i).map { |k| k['keyword'] }

        create_event payload: {
          'event_type' => 'new_keyword_targets',
          'keywords' => top,
          'week_of' => Date.today.beginning_of_week.to_s,
          'generated_at' => Time.now.utc.iso8601
        }
      end
    end
  end
end
