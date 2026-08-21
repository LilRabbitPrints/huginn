module Agents
  class EtsyListingFilterAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **EtsyListingFilterAgent** receives listing events from EtsyListingsAgent and re-emits them
      sorted and filtered by their revival potential score (views + favourers weighted sum).

      Only listings whose score meets `min_score` are forwarded. Listings are emitted with a
      `revival_score` field appended to the payload.

      **Options:**
      - `views_weight` — multiplier for the `views` field (default: 1)
      - `favorers_weight` — multiplier for the `num_favorers` field (default: 3)
      - `min_score` — minimum weighted score to pass the filter (default: 0)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits the original listing payload with an added `revival_score` field:

          {
            "listing_id": 1234567890,
            "title": "...",
            "revival_score": 124,
            ...all original listing fields...
          }
    MD

    def default_options
      {
        'views_weight' => 1,
        'favorers_weight' => 3,
        'min_score' => 0,
        'expected_receive_period_in_days' => 2
      }
    end

    def validate_options
      %w[views_weight favorers_weight min_score].each do |k|
        errors.add(:base, "#{k} must be a number") unless options[k].to_s =~ /\A\d+(\.\d+)?\z/
      end
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload.dup
        views = payload['views'].to_f
        favorers = payload['num_favorers'].to_f
        score = (views * interpolated['views_weight'].to_f) +
                (favorers * interpolated['favorers_weight'].to_f)

        next if score < interpolated['min_score'].to_f

        payload['revival_score'] = score.round(2)
        create_event payload: payload
      end
    end
  end
end
