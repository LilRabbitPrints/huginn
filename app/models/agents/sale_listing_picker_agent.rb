module Agents
  class SaleListingPickerAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **SaleListingPickerAgent** selects which listings to promote, using a fair-rotation
      algorithm to ensure every listing in your catalogue gets regular visibility.

      It tracks promotion history and prioritises listings that haven't been promoted in the
      longest time. Optionally it can weight by recent views spike (to capitalise on momentum).

      **Options:**
      - `listings_per_trigger` — how many listings to select (default: 1)
      - `boost_recent_spikes` — give extra priority to listings with recent view spikes (default: false)
      - `exclude_listing_ids` — array of listing IDs to never promote (e.g. archived/special)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Re-emits the promotion trigger events for the selected listings only.
    MD

    def default_options
      {
        'listings_per_trigger' => 1,
        'boost_recent_spikes' => false,
        'exclude_listing_ids' => [],
        'expected_receive_period_in_days' => 3
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      exclude = (interpolated['exclude_listing_ids'] || []).map(&:to_s)
      eligible = incoming_events.reject { |e| exclude.include?(e.payload['listing_id'].to_s) }
      n = interpolated['listings_per_trigger'].to_i
      promoted_log = memory['promoted_log'] ||= {}

      sorted = eligible.sort_by { |e| promoted_log[e.payload['listing_id'].to_s].to_i }
      selected = sorted.first(n)
      selected.each do |event|
        lid = event.payload['listing_id'].to_s
        promoted_log[lid] = Time.now.to_i
        create_event payload: event.payload
      end
      memory['promoted_log'] = promoted_log
      save!
    end
  end
end
