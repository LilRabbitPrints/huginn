module Agents
  class OpenAiListingBriefAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **OpenAiListingBriefAgent** receives a listing event and uses the OpenAI Chat Completions
      API to generate a complete, optimized listing brief including:
      - Optimized 140-char Etsy title (front-loaded keyword)
      - Exactly 13 Etsy tags
      - Short description (160 chars) and long description
      - Personalization hook and bulk order pitch
      - Diagnosis of why the listing may have underperformed

      The brief is emitted as a structured event for downstream agents.

      **Options:**
      - `api_key` — OpenAI API key
      - `model` — OpenAI model (default: `gpt-4o`)
      - `shop_name` — Your Etsy shop name (for context in the prompt)
      - `product_niche` — Short description of your product niche (e.g., "personalised rabbit prints")
      - `bulk_pricing_summary` — e.g., "5–9: 10% off, 10–24: 20% off, 25+: 30% off"
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits an enriched payload:

          {
            "listing_id": 1234567890,
            "original_title": "...",
            "optimized_title": "Personalised Rabbit Print | Bunny Nursery Wall Art...",
            "tags": ["personalised rabbit print", ...],
            "short_description": "...",
            "long_description": "...",
            "personalization_hook": "...",
            "bulk_order_pitch": "...",
            "diagnosis": "...",
            "seo_score": 87,
            ...original listing fields...
          }
    MD

    def default_options
      {
        'api_key' => '',
        'model' => 'gpt-4o',
        'shop_name' => 'Lil Rabbit Prints',
        'product_niche' => 'personalised rabbit prints and bunny-themed gifts',
        'bulk_pricing_summary' => '5-9: 10% off, 10-24: 20% off, 25+: 30% off',
        'expected_receive_period_in_days' => 2
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
        brief = generate_brief(event.payload)
        next unless brief

        create_event payload: event.payload.merge(brief)
      end
    end

    private

    def generate_brief(listing)
      prompt = build_prompt(listing)
      response = faraday.post(
        'https://api.openai.com/v1/chat/completions',
        {
          model: interpolated['model'],
          response_format: { type: 'json_object' },
          messages: [
            { role: 'system', content: system_prompt },
            { role: 'user', content: prompt }
          ],
          temperature: 0.7
        }.to_json,
        {
          'Authorization' => "******'api_key']}",
          'Content-Type' => 'application/json'
        }
      )
      raise "OpenAI error #{response.status}: #{response.body}" unless response.success?

      JSON.parse(JSON.parse(response.body).dig('choices', 0, 'message', 'content'))
    rescue StandardError => e
      error("OpenAiListingBriefAgent error for listing #{listing['listing_id']}: #{e.message}")
      nil
    end

    def system_prompt
      <<~PROMPT
        You are an expert Etsy SEO copywriter specialising in #{interpolated['product_niche']} for the shop "#{interpolated['shop_name']}".
        Respond with a valid JSON object containing exactly these keys:
        optimized_title (string, max 140 chars, primary keyword in first 3 words),
        tags (array of exactly 13 strings, mix of exact-match, long-tail, and buyer-intent phrases),
        short_description (string, max 160 chars, keyword in first sentence),
        long_description (string, 300-500 words, keyword-rich, mentions personalisation and bulk orders),
        personalization_hook (string, 1-2 sentences encouraging personalisation),
        bulk_order_pitch (string, 2-3 sentences with pricing: #{interpolated['bulk_pricing_summary']}),
        diagnosis (string, 2-3 sentences explaining likely reasons for underperformance),
        seo_score (integer 0-100).
      PROMPT
    end

    def build_prompt(listing)
      <<~PROMPT
        Listing to optimise:
        Title: #{listing['title']}
        Description: #{listing['description']&.truncate(500)}
        Current tags: #{listing['tags']&.join(', ')}
        Views: #{listing['views']}, Favourers: #{listing['num_favorers']}
        State: #{listing['state']}
        Please generate a complete listing brief to revive this listing.
      PROMPT
    end
  end
end
