module Agents
  class DescriptionWriterAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **DescriptionWriterAgent** writes the full Etsy listing description — both a short
      hook (first 160 chars, keyword-front-loaded for search snippet) and a long-form body
      (300–500 words) that includes:
      - Personalisation hook and customisation instructions
      - Bulk order pitch with tiered pricing
      - Materials, dimensions, and production time
      - Shipping info and packaging description
      - Clear call-to-action

      **Options:**
      - `api_key` — OpenAI API key
      - `model` — OpenAI model (default: `gpt-4o`)
      - `bulk_pricing` — Tiered pricing string (default: "5-9: 10% off, 10-24: 20% off, 25+: 30% off")
      - `production_time` — e.g., "1-3 business days"
      - `shipping_info` — e.g., "Tracked Royal Mail. UK: 2-4 days. Worldwide: 7-14 days."
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `short_description` and `long_description` fields populated/refined.
    MD

    def default_options
      {
        'api_key' => '',
        'model' => 'gpt-4o',
        'bulk_pricing' => '5-9: 10% off, 10-24: 20% off, 25+: 30% off',
        'production_time' => '1-3 business days',
        'shipping_info' => 'Tracked Royal Mail. UK: 2-4 days. Worldwide: 7-14 days.',
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
        descriptions = write_descriptions(event.payload)
        next unless descriptions

        create_event payload: event.payload.merge(descriptions)
      end
    end

    private

    def write_descriptions(payload)
      prompt = <<~PROMPT
        You are a conversion copywriter for an Etsy shop called Lil Rabbit Prints selling personalised rabbit prints and bunny gifts.

        Write a listing description for this product. Respond with a JSON object containing:
        - short_description: max 160 chars, primary keyword in first sentence, ends with personalisation CTA
        - long_description: 300-500 words structured as:
          1. Opening hook (keyword-rich, emotional)
          2. What it is and why buyers love it
          3. Personalisation section: what can be personalised, how to instruct at checkout
          4. Bulk orders: "#{interpolated['bulk_pricing']}" — perfect for corporate gifts, hen parties, school events
          5. Product details: materials, print quality, dimensions
          6. Production time: #{interpolated['production_time']}
          7. Shipping: #{interpolated['shipping_info']}
          8. Closing CTA: "Message me with any questions — I'd love to create something special for you!"

        Product title: #{payload['optimized_title'] || payload['title']}
        Current description (for context): #{payload['description']&.truncate(300)}

        Respond with ONLY a valid JSON object.
      PROMPT

      response = faraday.post(
        'https://api.openai.com/v1/chat/completions',
        {
          model: interpolated['model'],
          response_format: { type: 'json_object' },
          messages: [{ role: 'user', content: prompt }],
          temperature: 0.7
        }.to_json,
        {
          'Authorization' => "******'api_key']}",
          'Content-Type' => 'application/json'
        }
      )
      raise "OpenAI error #{response.status}" unless response.success?

      JSON.parse(JSON.parse(response.body).dig('choices', 0, 'message', 'content'))
    rescue StandardError => e
      error("DescriptionWriterAgent error: #{e.message}")
      nil
    end
  end
end
