module Agents
  class OutboundWebhookAuthAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **OutboundWebhookAuthAgent** acts as an authenticated proxy for outbound webhook calls.
      It receives events and fires them as POST requests to a configured URL, attaching the
      correct authentication headers for the target app.

      This prevents API keys from being scattered across multiple agents — centralise auth here.

      **Options:**
      - `target_url` — URL to POST to
      - `auth_type` — `bearer`, `header`, or `basic` (default: `bearer`)
      - `auth_value` — the token/key/credentials value
      - `auth_header_name` — header name for `header` auth type (default: `X-API-Key`)
      - `include_fields` — array of payload fields to include (empty = all fields)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits the HTTP response as an event (status, body) for downstream handling.
    MD

    def default_options
      {
        'target_url' => '',
        'auth_type' => 'bearer',
        'auth_value' => '',
        'auth_header_name' => 'X-API-Key',
        'include_fields' => [],
        'expected_receive_period_in_days' => 2
      }
    end

    def validate_options
      errors.add(:base, 'target_url is required') if options['target_url'].blank?
      errors.add(:base, 'auth_type must be bearer, header, or basic') unless
        %w[bearer header basic].include?(options['auth_type'])
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = filter_payload(event.payload)
        auth_headers = build_auth_headers
        response = faraday.post(
          interpolated['target_url'],
          payload.to_json,
          { 'Content-Type' => 'application/json' }.merge(auth_headers)
        )
        create_event payload: {
          'status' => response.status,
          'success' => response.success?,
          'body_preview' => response.body.to_s.truncate(200),
          'original_payload' => payload
        }
      rescue StandardError => e
        error("OutboundWebhookAuthAgent error: #{e.message}")
      end
    end

    private

    def filter_payload(payload)
      fields = interpolated['include_fields'] || []
      return payload if fields.empty?

      payload.slice(*fields)
    end

    def build_auth_headers
      case interpolated['auth_type']
      when 'bearer'
        { 'Authorization' => "******'auth_value']}" }
      when 'header'
        { interpolated['auth_header_name'] => interpolated['auth_value'] }
      when 'basic'
        { 'Authorization' => "Basic #{Base64.strict_encode64(interpolated['auth_value'])}" }
      else
        {}
      end
    end
  end
end
