module Agents
  class EtsyListingDedupAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **EtsyListingDedupAgent** prevents already-revived listings from re-entering the
      revival pipeline. It tracks `listing_id` values that have been forwarded and only emits
      events for listings it has not seen before (or whose `force_re_revive` flag is set).

      **Options:**
      - `memory_ttl_days` — how many days to remember a listing_id before allowing it through again
        (0 = remember forever, default: 90)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Re-emits the original listing payload unchanged for new/unseen listings.
    MD

    def default_options
      {
        'memory_ttl_days' => 90,
        'expected_receive_period_in_days' => 2
      }
    end

    def validate_options
      errors.add(:base, 'memory_ttl_days must be a non-negative integer') unless
        options['memory_ttl_days'].to_s =~ /\A\d+\z/
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        listing_id = event.payload['listing_id'].to_s
        next if seen_recently?(listing_id) && !event.payload['force_re_revive']

        mark_seen(listing_id)
        create_event payload: event.payload
      end
    end

    private

    def seen_recently?(listing_id)
      seen = memory['seen'] ||= {}
      ts = seen[listing_id]
      return false unless ts

      ttl = interpolated['memory_ttl_days'].to_i
      return false if ttl.zero?

      Time.now.to_i - ts < ttl * 86_400
    end

    def mark_seen(listing_id)
      memory['seen'] ||= {}
      memory['seen'][listing_id] = Time.now.to_i
      save!
    end
  end
end
