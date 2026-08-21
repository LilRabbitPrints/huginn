module Agents
  class CouponAnnouncerAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **CouponAnnouncerAgent** receives a coupon_created event and uses OpenAI to embed
      the coupon code naturally into the week's social media copy across all platforms.

      **Options:**
      - `api_key` — OpenAI API key
      - `etsy_shop_url` — your shop URL
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits platform-specific coupon announcement copy:

          {
            "event_type": "coupon_announcement",
            "coupon_code": "BUNNY15",
            "twitter": "...",
            "threads": "...",
            "pinterest": "...",
            "email_subject": "...",
            "email_body": "..."
          }
    MD

    def default_options
      {
        'api_key' => '',
        'etsy_shop_url' => 'https://www.etsy.com/shop/LilRabbitPrints',
        'expected_receive_period_in_days' => 8
      }
    end

    def validate_options
      errors.add(:base, 'api_key is required') if options['api_key'].blank?
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        next unless payload['event_type'] == 'coupon_created'

        copy = generate_copy(payload)
        next unless copy

        create_event payload: {
          'event_type' => 'coupon_announcement',
          'coupon_code' => payload['coupon_code'],
          'discount_pct' => payload['discount_pct'],
          'valid_until' => payload['valid_until']
        }.merge(copy)
      end
    end

    private

    def generate_copy(payload)
      code = payload['coupon_code']
      pct = payload['discount_pct']
      until_date = payload['valid_until']
      shop_url = interpolated['etsy_shop_url']

      prompt = <<~PROMPT
        You are a social media copywriter for Lil Rabbit Prints, a UK Etsy shop selling personalised rabbit prints.
        Write coupon announcement copy. The code is "#{code}" for #{pct}% off, valid until #{until_date}.
        Shop: #{shop_url}
        Embed the code naturally — don't just list it. Make it feel like a gift to the reader.
        Return a JSON object with keys: twitter (max 280 chars), threads (200-400 chars), pinterest (200-400 chars), email_subject (max 60 chars), email_body (100-150 words).
        Respond with ONLY a valid JSON object.
      PROMPT

      response = faraday.post(
        'https://api.openai.com/v1/chat/completions',
        { model: 'gpt-4o', response_format: { type: 'json_object' }, messages: [{ role: 'user', content: prompt }], temperature: 0.8 }.to_json,
        { 'Authorization' => "******'api_key']}", 'Content-Type' => 'application/json' }
      )
      raise "OpenAI error #{response.status}" unless response.success?

      JSON.parse(JSON.parse(response.body).dig('choices', 0, 'message', 'content'))
    rescue StandardError => e
      error("CouponAnnouncerAgent error: #{e.message}")
      nil
    end
  end
end
