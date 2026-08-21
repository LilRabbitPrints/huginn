module Agents
  class SaleCopyGeneratorAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **SaleCopyGeneratorAgent** uses OpenAI to generate platform-specific promotional copy
      for each listing being promoted. It creates:
      - Twitter/X post (max 280 chars, punchy + hashtags + link)
      - Threads post (conversational, 200–400 chars)
      - Pinterest description (keyword-dense, 200-500 chars, no hashtags)
      - Email subject line (max 60 chars, urgency-driven)
      - Email body (short, 100-150 words)

      **Options:**
      - `api_key` — OpenAI API key
      - `model` — OpenAI model (default: `gpt-4o`)
      - `etsy_shop_url` — your Etsy shop URL for inclusion in posts
      - `active_coupon_code` — optional coupon code to embed (leave blank if none)
      - `brand_voice` — description of your brand voice (e.g., "warm, playful, personal")
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `social_copy: {twitter, threads, pinterest, email_subject, email_body}`.
    MD

    def default_options
      {
        'api_key' => '',
        'model' => 'gpt-4o',
        'etsy_shop_url' => 'https://www.etsy.com/shop/LilRabbitPrints',
        'active_coupon_code' => '',
        'brand_voice' => 'warm, playful, personal, small-business pride',
        'expected_receive_period_in_days' => 3
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
        copy = generate_copy(event.payload)
        next unless copy

        create_event payload: event.payload.merge('social_copy' => copy)
      end
    end

    private

    def generate_copy(payload)
      coupon = interpolated['active_coupon_code'].presence
      coupon_line = coupon ? "Use code #{coupon} for a discount. " : ''
      listing_url = payload['listing_url']
      prompt = <<~PROMPT
        You are a social media copywriter for Lil Rabbit Prints — a UK Etsy shop selling personalised rabbit prints and bunny gifts.
        Brand voice: #{interpolated['brand_voice']}

        Product being promoted:
        Title: #{payload['title']}
        Price: #{payload['currency_code']} #{payload['price']}
        Tags/keywords: #{payload['tags']&.first(5)&.join(', ')}
        Listing URL: #{listing_url}
        #{coupon_line}

        Generate platform-specific copy as a JSON object with these keys:
        - twitter: max 280 chars, punchy, 2-3 relevant hashtags, ends with the listing URL
        - threads: conversational, 200-400 chars, warm tone, ends with listing URL
        - pinterest: keyword-dense description 200-500 chars, no hashtags, 3-5 naturally embedded keywords
        - email_subject: max 60 chars, urgency or curiosity-driven
        - email_body: 100-150 words, personal, ends with clear CTA to shop link

        Respond with ONLY a valid JSON object.
      PROMPT

      response = faraday.post(
        'https://api.openai.com/v1/chat/completions',
        { model: interpolated['model'], response_format: { type: 'json_object' }, messages: [{ role: 'user', content: prompt }], temperature: 0.8 }.to_json,
        { 'Authorization' => "******'api_key']}", 'Content-Type' => 'application/json' }
      )
      raise "OpenAI error #{response.status}" unless response.success?

      JSON.parse(JSON.parse(response.body).dig('choices', 0, 'message', 'content'))
    rescue StandardError => e
      error("SaleCopyGeneratorAgent error: #{e.message}")
      nil
    end
  end
end
