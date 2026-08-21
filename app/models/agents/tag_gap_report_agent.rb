module Agents
  class TagGapReportAgent < Agent
    include WebRequestConcern

    default_schedule "every_7d"

    description <<~MD
      The **TagGapReportAgent** fetches all tags currently used across your active Etsy listings,
      compares them against the latest consolidated keyword list, and identifies gaps — keywords
      buyers are searching for that you're not targeting.

      It emits a gap report event for downstream agents to email you.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `top_gaps_to_report` — number of top gap keywords to include in report (default: 20)
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits:

          {
            "event_type": "tag_gap_report",
            "current_tag_count": 156,
            "gap_keywords": [
              {"keyword": "bunny nursery art uk", "score": 36.0},
              ...
            ],
            "generated_at": "..."
          }
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
        'top_gaps_to_report' => 20,
        'expected_update_period_in_days' => 8
      }
    end

    def validate_options
      errors.add(:base, 'shop_id is required') if options['shop_id'].blank?
      errors.add(:base, 'api_key is required') if options['api_key'].blank?
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def check
      current_tags = fetch_all_current_tags
      trending_keywords = memory['latest_keyword_list'] || []
      gaps = find_gaps(current_tags, trending_keywords)

      create_event payload: {
        'event_type' => 'tag_gap_report',
        'current_tag_count' => current_tags.size,
        'unique_current_tags' => current_tags.uniq.size,
        'gap_keywords' => gaps.first(interpolated['top_gaps_to_report'].to_i),
        'generated_at' => Time.now.utc.iso8601
      }
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        if event.payload['event_type'] == 'consolidated_keywords'
          memory['latest_keyword_list'] = event.payload['keyword_list'] || []
          save!
        end
      end
    end

    private

    def fetch_all_current_tags
      response = faraday.get(
        "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/listings",
        { state: 'active', limit: 100 },
        { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}" }
      )
      return [] unless response.success?

      (JSON.parse(response.body)['results'] || []).flat_map { |l| l['tags'] || [] }
    rescue StandardError => e
      error("TagGapReportAgent fetch error: #{e.message}")
      []
    end

    def find_gaps(current_tags, trending)
      current_set = current_tags.map(&:downcase).to_set
      trending.reject { |kw| current_set.include?(kw['keyword'].to_s.downcase) }
    end
  end
end
