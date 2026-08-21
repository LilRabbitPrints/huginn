module Agents
  class AuditActionQueueAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **AuditActionQueueAgent** receives SEO audit events and routes listings that fail
      audit back into the revival pipeline for reprocessing. It acts as a decision gate:
      - Listings with `audit_passed: false` are pushed back into the revival queue
      - Listings with `audit_passed: true` are forwarded downstream (e.g., to the social promotion pipeline)

      It prevents the same listing from being re-queued more than `max_requeue_attempts` times
      to avoid infinite loops.

      **Options:**
      - `max_requeue_attempts` — maximum times to re-queue a failing listing (default: 3)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits events with `action: "requeue"` or `action: "pass"` plus original payload.
    MD

    def default_options
      {
        'max_requeue_attempts' => 3,
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        listing_id = payload['listing_id'].to_s
        passed = payload['audit_passed']

        if passed
          create_event payload: payload.merge('action' => 'pass')
          clear_attempt(listing_id)
          next
        end

        attempts = increment_attempt(listing_id)
        max = interpolated['max_requeue_attempts'].to_i

        if attempts > max
          log("AuditActionQueueAgent: listing #{listing_id} exceeded max requeue attempts (#{max}), skipping")
          create_event payload: payload.merge('action' => 'max_attempts_exceeded', 'requeue_attempts' => attempts)
        else
          log("AuditActionQueueAgent: re-queueing listing #{listing_id} (attempt #{attempts}/#{max})")
          create_event payload: payload.merge('action' => 'requeue', 'requeue_attempts' => attempts)
        end
      end
    end

    private

    def increment_attempt(listing_id)
      queue = memory['requeue_counts'] ||= {}
      queue[listing_id] = queue[listing_id].to_i + 1
      memory['requeue_counts'] = queue
      save!
      queue[listing_id]
    end

    def clear_attempt(listing_id)
      queue = memory['requeue_counts'] ||= {}
      queue.delete(listing_id)
      memory['requeue_counts'] = queue
      save!
    end
  end
end
