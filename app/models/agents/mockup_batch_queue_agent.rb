module Agents
  class MockupBatchQueueAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **MockupBatchQueueAgent** accumulates individual listing mockup requests and groups
      them into batch jobs to reduce API calls to your mockup generator app. It holds
      incoming requests until either `batch_size` is reached or `max_wait_minutes` elapses.

      **Options:**
      - `batch_size` — number of listings to batch before dispatching (default: 5)
      - `max_wait_minutes` — maximum minutes to wait before flushing the queue (default: 30)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "mockup_batch_ready", batch_size: N, listings: [...]}` when the
      batch is ready to dispatch.
    MD

    def default_options
      {
        'batch_size' => 5,
        'max_wait_minutes' => 30,
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      queue = memory['queue'] ||= []
      incoming_events.each do |event|
        queue << { 'payload' => event.payload, 'queued_at' => Time.now.to_i }
      end
      memory['queue'] = queue
      save!
      flush_if_ready!
    end

    private

    def flush_if_ready!
      queue = memory['queue'] ||= []
      return if queue.empty?

      batch_size = interpolated['batch_size'].to_i
      max_wait = interpolated['max_wait_minutes'].to_f * 60
      oldest_age = Time.now.to_i - queue.first['queued_at'].to_i
      should_flush = queue.size >= batch_size || oldest_age >= max_wait

      return unless should_flush

      to_dispatch = queue.shift(batch_size)
      memory['queue'] = queue
      save!

      create_event payload: {
        'event_type' => 'mockup_batch_ready',
        'batch_size' => to_dispatch.size,
        'listings' => to_dispatch.map { |i| i['payload'] },
        'dispatched_at' => Time.now.utc.iso8601
      }
      log("MockupBatchQueueAgent: flushed batch of #{to_dispatch.size}")
    end
  end
end
