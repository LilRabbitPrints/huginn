module Agents
  class TopOpportunityAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **TopOpportunityAgent** receives SEO audit events and identifies the top 3 listings
      that are closest to page 1 on Etsy search but need one small fix — the highest-value
      optimisation targets for the week.

      "Closest to page 1" is estimated by: high views + high score (meaning the listing is
      almost there, just needs one or two improvements).

      **Options:**
      - `top_n` — number of top opportunities to emit (default: 3)
      - `min_views` — minimum views to be considered a high-potential listing (default: 50)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits a single event with the top N opportunity listings.
    MD

    def default_options
      {
        'top_n' => 3,
        'min_views' => 50,
        'expected_receive_period_in_days' => 8
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      candidates = memory['candidates'] ||= []
      incoming_events.each do |event|
        payload = event.payload
        next unless payload['event_type'] == 'listing_seo_audit'
        next if payload['audit_passed']
        next if payload['views'].to_i < interpolated['min_views'].to_i

        candidates << payload
      end
      memory['candidates'] = candidates.last(500)
      save!

      top = candidates
            .sort_by { |c| -(c['audit_score'].to_i + c['views'].to_i / 10) }
            .first(interpolated['top_n'].to_i)

      return if top.empty?

      create_event payload: {
        'event_type' => 'top_opportunities',
        'opportunities' => top.map { |c| c.slice('listing_id', 'title', 'audit_score', 'failures', 'views') },
        'generated_at' => Time.now.utc.iso8601
      }
    end
  end
end
