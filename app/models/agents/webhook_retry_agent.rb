module Agents
  class WebhookRetryAgent < Agent
    include WebRequestConcern

    default_schedule "every_5m"

    description <<~MD
      The **WebhookRetryAgent** retries failed outbound webhook calls with exponential backoff.
      It receives failure events (from OutboundWebhookAuthAgent or any agent that emits
      `success: false` responses) and re-attempts them up to `max_retries` times.

      Retry delays: attempt 1 = 5 min, attempt 2 = 15 min, attempt 3 = 45 min.

      **Options:**
      - `max_retries` — maximum retry attempts (default: 3)
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "webhook_retry_success", attempt: N}` or `{event_type: "webhook_retry_exhausted"}`.
    MD

    def default_options
      {
        'max_retries' => 3,
        'expected_update_period_in_days' => 1
      }
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def receive(incoming_events)
      queue = memory['retry_queue'] ||= []
      incoming_events.each do |event|
        payload = event.payload
        next if payload['success'] || payload['status'].to_i.between?(200, 299)

        url = payload['target_url'] || payload.dig('original_payload', 'target_url')
        body = payload['original_payload']
        next unless url && body

        queue << {
          'url' => url,
          'body' => body,
          'attempts' => 0,
          'next_retry_at' => Time.now.to_i + 300,
          'registered_at' => Time.now.to_i
        }
      end
      memory['retry_queue'] = queue
      save!
    end

    def check
      queue = memory['retry_queue'] ||= []
      max = interpolated['max_retries'].to_i
      completed = []

      queue.each_with_index do |item, i|
        next if Time.now.to_i < item['next_retry_at'].to_i

        response = fire_request(item['url'], item['body'])
        item['attempts'] = item['attempts'].to_i + 1

        if response&.success?
          create_event payload: { 'event_type' => 'webhook_retry_success', 'url' => item['url'], 'attempt' => item['attempts'] }
          completed << i
        elsif item['attempts'] >= max
          create_event payload: { 'event_type' => 'webhook_retry_exhausted', 'url' => item['url'], 'attempts' => item['attempts'] }
          completed << i
        else
          backoff = [5, 15, 45][item['attempts'].to_i] || 60
          item['next_retry_at'] = Time.now.to_i + backoff * 60
        end
      end

      completed.reverse.each { |i| queue.delete_at(i) }
      memory['retry_queue'] = queue
      save!
    end

    private

    def fire_request(url, body)
      faraday.post(url, body.to_json, { 'Content-Type' => 'application/json' })
    rescue StandardError => e
      error("WebhookRetryAgent fire error: #{e.message}")
      nil
    end
  end
end
