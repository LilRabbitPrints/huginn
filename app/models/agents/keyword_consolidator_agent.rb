module Agents
  class KeywordConsolidatorAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **KeywordConsolidatorAgent** deduplicates and ranks all keywords collected from
      EtsyAutoCompleteAgent, TwitterTrendAgent, and CompetitorTagAgent. It maintains a rolling
      keyword frequency map and emits a ranked list periodically.

      Keywords are scored by:
      - Frequency of appearance across sources
      - Source multiplier (etsy_autocomplete: 3×, competitor_tag: 2×, twitter_trend: 1×)
      - Recency (keywords from the last 7 days get a 1.5× boost)

      **Options:**
      - `emit_top_n` — number of top keywords to emit per consolidation (default: 50)
      - `consolidate_every_n_events` — emit consolidated list every N events received (default: 20)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits a single event with a ranked `keyword_list` array when consolidation fires:

          {
            "event_type": "consolidated_keywords",
            "keyword_list": [
              {"keyword": "personalised rabbit print", "score": 42.0, "sources": ["etsy_autocomplete", "competitor_tag"]},
              ...
            ],
            "consolidated_at": "..."
          }
    MD

    def default_options
      {
        'emit_top_n' => 50,
        'consolidate_every_n_events' => 20,
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      source_weights = { 'etsy_autocomplete' => 3.0, 'competitor_tag' => 2.0, 'twitter_trend' => 1.0 }
      kw_map = memory['kw_map'] ||= {}
      count = memory['event_count'] ||= 0

      incoming_events.each do |event|
        kw = event.payload['keyword'].to_s.downcase.strip
        next if kw.blank?

        source = event.payload['source'].to_s
        weight = source_weights[source] || 1.0
        recency_boost = recent?(event.payload['collected_at']) ? 1.5 : 1.0

        kw_map[kw] ||= { 'score' => 0.0, 'sources' => [], 'last_seen' => nil }
        kw_map[kw]['score'] += weight * recency_boost
        kw_map[kw]['sources'] = (kw_map[kw]['sources'] + [source]).uniq
        kw_map[kw]['last_seen'] = event.payload['collected_at']
        count += 1
      end

      memory['kw_map'] = kw_map
      memory['event_count'] = count
      save!

      return unless count >= interpolated['consolidate_every_n_events'].to_i

      emit_consolidated_list(kw_map)
      memory['event_count'] = 0
      save!
    end

    private

    def emit_consolidated_list(kw_map)
      top_n = interpolated['emit_top_n'].to_i
      ranked = kw_map.sort_by { |_, v| -v['score'] }.first(top_n).map do |kw, data|
        { 'keyword' => kw, 'score' => data['score'].round(2), 'sources' => data['sources'] }
      end
      create_event payload: {
        'event_type' => 'consolidated_keywords',
        'keyword_list' => ranked,
        'consolidated_at' => Time.now.utc.iso8601
      }
    end

    def recent?(timestamp_str)
      return false unless timestamp_str

      ts = Time.parse(timestamp_str) rescue nil
      ts && (Time.now - ts) < 7 * 86_400
    end
  end
end
