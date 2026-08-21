module Agents
  class MockupStatusPollerAgent < Agent
    include WebRequestConcern

    default_schedule "every_5m"

    description <<~MD
      The **MockupStatusPollerAgent** polls your mockup generator app's job status endpoint
      every 5 minutes for pending requests. When a job completes, it emits an event with the
      returned image URLs so the ListingImageUploaderAgent can proceed.

      **Options:**
      - `mockup_app_status_url` — URL pattern for job status endpoint (e.g., `https://yourapp.com/jobs/{request_id}/status`)
      - `mockup_app_secret` — auth secret
      - `poll_timeout_minutes` — give up polling after this many minutes (default: 60)
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "mockup_job_complete", request_id: ..., listing_id: ..., mockup_images: [...]}`.
    MD

    def default_options
      {
        'mockup_app_status_url' => '',
        'mockup_app_secret' => '',
        'poll_timeout_minutes' => 60,
        'expected_update_period_in_days' => 1
      }
    end

    def validate_options
      errors.add(:base, 'mockup_app_status_url is required') if options['mockup_app_status_url'].blank?
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def receive(incoming_events)
      pending = memory['pending'] ||= {}
      incoming_events.each do |event|
        payload = event.payload
        request_id = payload['mockup_request_id']
        next unless request_id

        pending[request_id] = {
          'request_id' => request_id,
          'listing_id' => payload['listing_id'],
          'payload' => payload,
          'registered_at' => Time.now.to_i
        }
      end
      memory['pending'] = pending
      save!
    end

    def check
      pending = memory['pending'] ||= {}
      timeout = interpolated['poll_timeout_minutes'].to_f * 60
      completed = []

      pending.each do |request_id, record|
        age = Time.now.to_i - record['registered_at'].to_i
        if age > timeout
          log("MockupStatusPollerAgent: request #{request_id} timed out")
          completed << request_id
          next
        end

        status_data = poll_status(request_id)
        next unless status_data

        case status_data['status']
        when 'complete', 'done', 'finished'
          create_event payload: {
            'event_type' => 'mockup_job_complete',
            'request_id' => request_id,
            'listing_id' => record['listing_id'],
            'mockup_images' => status_data['images'] || [],
            'completed_at' => Time.now.utc.iso8601
          }.merge(record['payload'])
          completed << request_id
          log("MockupStatusPollerAgent: request #{request_id} complete")
        when 'failed', 'error'
          create_event payload: { 'event_type' => 'mockup_job_failed', 'request_id' => request_id, 'listing_id' => record['listing_id'], 'error' => status_data['error'] }
          completed << request_id
        end
      end

      completed.each { |id| pending.delete(id) }
      memory['pending'] = pending
      save!
    end

    private

    def poll_status(request_id)
      url = interpolated['mockup_app_status_url'].gsub('{request_id}', request_id.to_s)
      response = faraday.get(url, {}, { 'X-Mockup-Secret' => interpolated['mockup_app_secret'] })
      return nil unless response.success?

      JSON.parse(response.body)
    rescue StandardError => e
      error("MockupStatusPollerAgent poll error for #{request_id}: #{e.message}")
      nil
    end
  end
end
