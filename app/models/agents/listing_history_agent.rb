module Agents
  class ListingHistoryAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **ListingHistoryAgent** keeps a full event log for each listing — recording when it was
      revived, which AI brief was used, which images were generated, when it was published,
      and how it has performed since going live.

      This history is stored in memory and can be queried by emitting a `listing_history_request`
      event with the desired `listing_id`.

      **Options:**
      - `max_history_per_listing` — max events to keep per listing (default: 50)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "listing_history_response", listing_id: ..., history: [...]}` when
      a `listing_history_request` is received.
    MD

    def default_options
      {
        'max_history_per_listing' => 50,
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      histories = memory['histories'] ||= {}
      max = interpolated['max_history_per_listing'].to_i

      incoming_events.each do |event|
        payload = event.payload
        listing_id = payload['listing_id'].to_s

        if payload['event_type'] == 'listing_history_request'
          history = histories[listing_id] || []
          create_event payload: {
            'event_type' => 'listing_history_response',
            'listing_id' => listing_id,
            'history' => history,
            'event_count' => history.size
          }
          next
        end

        next if listing_id.blank?

        histories[listing_id] ||= []
        histories[listing_id] << {
          'event_type' => payload['event_type'],
          'timestamp' => Time.now.utc.iso8601,
          'summary' => summarise_event(payload)
        }
        histories[listing_id] = histories[listing_id].last(max)
      end

      memory['histories'] = histories
      save!
    end

    private

    def summarise_event(payload)
      case payload['event_type']
      when 'state_transition' then "#{payload['from_state']} → #{payload['to_state']}"
      when 'listing_activated' then "Activated: #{payload['listing_url']}"
      when 'images_uploaded' then "#{payload['uploaded_count']} images uploaded"
      when 'promotion_trigger' then "Promoted on social media"
      when 'promotion_lift_report' then "+#{payload['views_lift']} views after promotion"
      else payload['event_type']
      end
    end
  end
end
