module Agents
  class MockupAppBridgeAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **MockupAppBridgeAgent** is the primary bridge between Huginn and your external bulk
      mockup generator application. It receives listing brief events, resolves the correct
      design file reference for each product type, and dispatches requests to your app.

      **Options:**
      - `mockup_app_url` — base URL of your mockup generator app
      - `mockup_app_secret` — auth secret (sent as `X-Mockup-Secret` header)
      - `design_file_map` — JSON map of shop_section_id or product_type to design file path/reference
      - `default_design_file` — fallback design file reference
      - `batch_mode` — group multiple listings into one batch request (default: false)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits a confirmation with `mockup_request_id` and full dispatch details.
    MD

    def default_options
      {
        'mockup_app_url' => '',
        'mockup_app_secret' => '',
        'design_file_map' => {},
        'default_design_file' => 'designs/default_rabbit.png',
        'batch_mode' => false,
        'expected_receive_period_in_days' => 2
      }
    end

    def validate_options
      errors.add(:base, 'mockup_app_url is required') if options['mockup_app_url'].blank?
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      if boolify(interpolated['batch_mode'])
        dispatch_batch(incoming_events)
      else
        incoming_events.each { |e| dispatch_single(e.payload) }
      end
    end

    private

    def dispatch_single(payload)
      design_file = resolve_design_file(payload)
      request_body = build_request(payload, design_file)
      result = post_to_mockup_app(request_body)
      return unless result

      create_event payload: {
        'mockup_request_id' => result['request_id'] || SecureRandom.hex(8),
        'listing_id' => payload['listing_id'],
        'design_file' => design_file,
        'product_type' => payload['product_type'],
        'dispatched_at' => Time.now.utc.iso8601
      }.merge(payload)
    end

    def dispatch_batch(events)
      items = events.map do |e|
        design_file = resolve_design_file(e.payload)
        build_request(e.payload, design_file)
      end
      result = post_to_mockup_app({ batch: items })
      return unless result

      events.each_with_index do |event, i|
        create_event payload: event.payload.merge(
          'mockup_request_id' => result.dig('request_ids', i) || SecureRandom.hex(8),
          'dispatched_at' => Time.now.utc.iso8601
        )
      end
    end

    def resolve_design_file(payload)
      map = interpolated['design_file_map'] || {}
      map[payload['product_type'].to_s] ||
        map[payload['shop_section_id'].to_s] ||
        interpolated['default_design_file']
    end

    def build_request(payload, design_file)
      {
        listing_id: payload['listing_id'],
        product_type: payload['product_type'],
        design_file: design_file,
        carousel_spec: payload['carousel_spec'],
        title: payload['optimized_title'] || payload['title']
      }
    end

    def post_to_mockup_app(body)
      response = faraday.post(
        interpolated['mockup_app_url'],
        body.to_json,
        { 'Content-Type' => 'application/json', 'X-Mockup-Secret' => interpolated['mockup_app_secret'] }
      )
      raise "Mockup app error #{response.status}: #{response.body}" unless response.success?

      JSON.parse(response.body)
    rescue StandardError => e
      error("MockupAppBridgeAgent error: #{e.message}")
      nil
    end
  end
end
