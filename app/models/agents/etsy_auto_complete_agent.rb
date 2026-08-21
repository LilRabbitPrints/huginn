module Agents
  class EtsyAutoCompleteAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **EtsyAutoCompleteAgent** scrapes Etsy's search autocomplete API to discover real
      buyer search phrases for a given seed keyword. These suggestions represent actual queries
      buyers are typing, making them extremely valuable for SEO targeting.

      It sends a request to Etsy's suggest endpoint and parses the returned suggestions.

      **Options:**
      - `max_suggestions` — max suggestions to collect per seed keyword (default: 10)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits one event per suggestion:

          {
            "keyword": "personalised rabbit print for nursery",
            "source": "etsy_autocomplete",
            "seed_keyword": "personalised rabbit print",
            "collected_at": "..."
          }
    MD

    def default_options
      {
        'max_suggestions' => 10,
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        seed = event.payload['seed_keyword'].to_s
        next if seed.blank?

        suggestions = fetch_suggestions(seed)
        suggestions.first(interpolated['max_suggestions'].to_i).each do |suggestion|
          create_event payload: {
            'keyword' => suggestion,
            'source' => 'etsy_autocomplete',
            'seed_keyword' => seed,
            'collected_at' => Time.now.utc.iso8601
          }
        end
      end
    end

    private

    def fetch_suggestions(query)
      response = faraday.get(
        'https://www.etsy.com/api/v3/ajax/bespoke/public/buyer/search/suggest',
        { query: query, limit: 10 },
        { 'Accept' => 'application/json', 'User-Agent' => 'Mozilla/5.0' }
      )
      return [] unless response.success?

      body = JSON.parse(response.body)
      body['results']&.map { |r| r['query'] || r['suggestion'] || r } || []
    rescue StandardError => e
      error("EtsyAutoCompleteAgent error for '#{query}': #{e.message}")
      []
    end
  end
end
