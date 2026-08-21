module Agents
  class GapAnalyzerAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **GapAnalyzerAgent** cross-references consolidated trending keywords against your
      current tag inventory to produce a prioritised gap analysis. It identifies:
      - Keywords with high search signal you're completely missing
      - Keywords you're using but could apply to more listings
      - Keyword clusters (e.g., "easter bunny" variations) where you're underrepresented

      **Options:**
      - `min_score_to_flag` — minimum keyword score to include in gaps (default: 5.0)
      - `cluster_similar` — group similar keywords into clusters (default: true)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits a gap analysis event with categorised gap keywords and keyword clusters.
    MD

    def default_options
      {
        'min_score_to_flag' => 5.0,
        'cluster_similar' => true,
        'expected_receive_period_in_days' => 4
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        case payload['event_type']
        when 'tag_inventory'
          memory['tag_inventory'] = payload
          save!
        when 'consolidated_keywords'
          memory['keyword_list'] = payload['keyword_list']
          save!
        end

        next unless memory['tag_inventory'] && memory['keyword_list']

        analyze_and_emit
      end
    end

    private

    def analyze_and_emit
      inventory = memory['tag_inventory']
      keywords = memory['keyword_list'] || []
      current_tags = (inventory['tag_frequency'] || {}).keys.to_set
      min_score = interpolated['min_score_to_flag'].to_f

      gaps = keywords.select do |kw|
        kw['score'].to_f >= min_score && !current_tags.include?(kw['keyword'].to_s.downcase)
      end

      clusters = boolify(interpolated['cluster_similar']) ? cluster_keywords(gaps) : {}

      create_event payload: {
        'event_type' => 'gap_analysis',
        'total_gaps' => gaps.size,
        'top_gaps' => gaps.first(30),
        'keyword_clusters' => clusters,
        'current_unique_tags' => current_tags.size,
        'analyzed_at' => Time.now.utc.iso8601
      }
    end

    def cluster_keywords(gaps)
      clusters = Hash.new { |h, k| h[k] = [] }
      gap_keywords = gaps.map { |g| g['keyword'] }
      common_roots = %w[bunny rabbit easter nursery personalised custom cottagecore gift print art wall]
      gap_keywords.each do |kw|
        root = common_roots.find { |r| kw.include?(r) } || 'other'
        clusters[root] << kw
      end
      clusters.reject { |_, v| v.empty? }
    end
  end
end
