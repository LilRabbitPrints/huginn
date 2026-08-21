module Agents
  class KeywordIntelligenceAgent < Agent
    include WebRequestConcern

    default_schedule "every_7d"

    description <<~MD
      The **KeywordIntelligenceAgent** is the master SEO intelligence gatherer. It runs weekly
      and triggers its sub-agents to collect trending keywords from multiple sources:
      - Etsy autocomplete suggestions
      - Twitter/X trending hashtags
      - Competitor listing tags

      It emits a trigger event that kicks off the sub-agent chain.

      **Options:**
      - `seed_keywords` — array of base keywords to research (default: rabbit print, bunny gift, etc.)
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits one trigger event per seed keyword:

          {
            "event_type": "keyword_research_trigger",
            "seed_keyword": "personalised rabbit print",
            "triggered_at": "..."
          }
    MD

    def default_options
      {
        'seed_keywords' => [
          'personalised rabbit print', 'bunny nursery art', 'custom rabbit gift',
          'cottagecore wall art', 'rabbit lover gift', 'personalised bunny print',
          'bunny home decor', 'rabbit birthday gift', 'easter bunny gift',
          'custom pet rabbit print', 'bunny wedding gift', 'rabbit new baby gift',
          'personalised animal print', 'woodland nursery print', 'rabbit christmas gift',
          'custom bunny portrait', 'rabbit wall art uk', 'personalised new home print',
          'bunny thank you gift', 'rabbit hen party gift'
        ],
        'expected_update_period_in_days' => 8
      }
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def check
      keywords = interpolated['seed_keywords'] || []
      keywords.each do |keyword|
        create_event payload: {
          'event_type' => 'keyword_research_trigger',
          'seed_keyword' => keyword,
          'triggered_at' => Time.now.utc.iso8601
        }
      end
      log("KeywordIntelligenceAgent triggered research for #{keywords.size} seed keywords")
    end
  end
end
