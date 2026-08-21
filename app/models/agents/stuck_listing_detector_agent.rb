module Agents
  class StuckListingDetectorAgent < Agent
    default_schedule "every_6h"

    description <<~MD
      The **StuckListingDetectorAgent** checks the listing state map from ListingStateManagerAgent
      and flags any listing that hasn't advanced state in more than `stuck_threshold_hours` hours.

      Stuck listings are emitted as alert events for the NotificationCenterAgent to escalate.

      **Options:**
      - `stuck_threshold_hours` — hours without state change before flagging (default: 48)
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "stuck_listing_alert", listing_id: ..., current_state: ..., stuck_hours: ...}`.
    MD

    def default_options
      {
        'stuck_threshold_hours' => 48,
        'expected_update_period_in_days' => 2
      }
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        next unless event.payload['event_type'] == 'state_transition'

        state_map = memory['state_map'] ||= {}
        listing_id = event.payload['listing_id'].to_s
        state_map[listing_id] = {
          'state' => event.payload['to_state'],
          'updated_at' => Time.now.to_i
        }
        memory['state_map'] = state_map
        save!
      end
    end

    def check
      state_map = memory['state_map'] ||= {}
      threshold = interpolated['stuck_threshold_hours'].to_f * 3600
      terminal_states = %w[live closed failed]

      state_map.each do |listing_id, entry|
        next if terminal_states.include?(entry['state'])

        age = Time.now.to_i - entry['updated_at'].to_i
        next unless age > threshold

        hours_stuck = (age / 3600.0).round(1)
        create_event payload: {
          'event_type' => 'stuck_listing_alert',
          'listing_id' => listing_id,
          'current_state' => entry['state'],
          'stuck_hours' => hours_stuck,
          'alert' => "⚠️ Listing #{listing_id} has been stuck in '#{entry['state']}' for #{hours_stuck} hours",
          'detected_at' => Time.now.utc.iso8601
        }
        log("StuckListingDetectorAgent: listing #{listing_id} stuck in #{entry['state']} for #{hours_stuck}h")
      end
    end
  end
end
