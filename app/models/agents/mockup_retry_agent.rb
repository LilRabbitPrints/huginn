module Agents
  class MockupRetryAgent < Agent
    include WebRequestConcern

    default_schedule "every_5m"

    description <<~MD
      The **MockupRetryAgent** monitors pending mockup requests and automatically re-fires
      the webhook to your mockup generator app if no response has been received within
      `retry_after_minutes` minutes.

      It checks its memory for pending requests on every scheduled run and retries any that
      have exceeded the timeout. After `max_retries` attempts, the listing is flagged as
      `mockup_failed` and an alert event is emitted.

      **Options:**
      - `mockup_app_url` — Webhook URL of your mockup generator app
      - `mockup_app_secret` — Auth header value
      - `retry_after_minutes` — minutes before first retry (default: 30)
      - `max_retries` — maximum retry attempts before giving up (default: 3)
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits a `mockup_retry` event when re-firing, or a `mockup_failed` event when max retries
      are exhausted. Payload includes `listing_id`, `attempt`, and `carousel_spec`.
    MD

    def default_options
      {
        'mockup_app_url' => '',
        'mockup_app_secret' => '',
        'retry_after_minutes' => 30,
        'max_retries' => 3,
        'expected_update_period_in_days' => 1
      }
    end

    def validate_options
      errors.add(:base, 'mockup_app_url is required') if options['mockup_app_url'].blank?
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        listing_id = payload['listing_id'].to_s
        next if payload['mockup_images'].present?

        queue = memory['pending'] ||= {}
        queue[listing_id] = {
          'listing_id' => listing_id,
          'carousel_spec' => payload['carousel_spec'],
          'registered_at' => Time.now.to_i,
          'attempts' => 0
        }
        memory['pending'] = queue
        save!
      end
    end

    def check
      queue = memory['pending'] ||= {}
      threshold = interpolated['retry_after_minutes'].to_i * 60
      max = interpolated['max_retries'].to_i

      queue.each do |listing_id, entry|
        age = Time.now.to_i - entry['registered_at'].to_i
        next if age < threshold

        attempts = entry['attempts'].to_i
        if attempts >= max
          create_event payload: { 'event_type' => 'mockup_failed', 'listing_id' => listing_id, 'attempts' => attempts }
          queue.delete(listing_id)
          next
        end

        success = fire_retry(listing_id, entry['carousel_spec'])
        if success
          entry['attempts'] = attempts + 1
          entry['registered_at'] = Time.now.to_i
          create_event payload: { 'event_type' => 'mockup_retry', 'listing_id' => listing_id, 'attempt' => attempts + 1 }
        end
      end
      memory['pending'] = queue
      save!
    end

    private

    def fire_retry(listing_id, spec)
      response = faraday.post(
        interpolated['mockup_app_url'],
        { listing_id: listing_id, carousel_spec: spec, retry: true }.to_json,
        { 'Content-Type' => 'application/json', 'X-Mockup-Secret' => interpolated['mockup_app_secret'] }
      )
      response.success?
    rescue StandardError => e
      error("MockupRetryAgent error for listing #{listing_id}: #{e.message}")
      false
    end
  end
end
