module Agents
  class BulkQuoteDrafterAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **BulkQuoteDrafterAgent** receives confirmed bulk inquiry events and uses OpenAI to
      draft a personalised, conversion-optimised quote response. The draft is emailed to you
      for review before sending — keeping the response human and personal.

      **Options:**
      - `api_key` — OpenAI API key
      - `pricing_tiers` — JSON pricing tiers for bulk
      - `production_times` — JSON turnaround times per quantity range
      - `packaging_options` — description of packaging options for bulk
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "bulk_quote_draft", draft_response: "...", conversation_id: ..., buyer_name: ...}`.
    MD

    def default_options
      {
        'api_key' => '',
        'pricing_tiers' => '5-9: 10% off, 10-24: 20% off, 25-49: 30% off, 50+: message for custom quote',
        'production_times' => '1-9: 1-3 days, 10-24: 3-5 days, 25+: 5-7 days',
        'packaging_options' => 'Individual tissue wrapping available, custom branded bags for 20+, bulk box packaging for 50+',
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
        payload = event.payload
        draft = draft_quote_response(payload)
        next unless draft

        create_event payload: {
          'event_type' => 'bulk_quote_draft',
          'conversation_id' => payload['conversation_id'],
          'buyer_name' => payload['buyer_name'],
          'detected_keywords' => payload['detected_keywords'],
          'draft_response' => draft,
          'generated_at' => Time.now.utc.iso8601
        }
      end
    end

    private

    def draft_quote_response(payload)
      prompt = <<~PROMPT
        You are replying to a bulk/wholesale inquiry for Lil Rabbit Prints, a UK Etsy shop.
        Buyer: #{payload['buyer_name']}
        Their message context: "#{payload['message_preview']}"
        Detected intent keywords: #{payload['detected_keywords']&.join(', ')}

        Write a warm, professional reply that:
        1. Addresses them by name
        2. Thanks them for their interest
        3. Shares the bulk pricing: #{interpolated['pricing_tiers']}
        4. Mentions production times: #{interpolated['production_times']}
        5. Mentions packaging: #{interpolated['packaging_options']}
        6. Asks 2 clarifying questions to understand their needs (quantity, occasion, personalisation details)
        7. Ends with an invitation to continue the conversation

        Keep it warm and personal, not corporate. Max 200 words.
        Respond with ONLY the message text (no subject line, no JSON).
      PROMPT

      response = faraday.post(
        'https://api.openai.com/v1/chat/completions',
        { model: 'gpt-4o', messages: [{ role: 'user', content: prompt }], temperature: 0.7, max_tokens: 350 }.to_json,
        { 'Authorization' => "******'api_key']}", 'Content-Type' => 'application/json' }
      )
      raise "OpenAI error #{response.status}" unless response.success?

      JSON.parse(response.body).dig('choices', 0, 'message', 'content').to_s.strip
    rescue StandardError => e
      error("BulkQuoteDrafterAgent error: #{e.message}")
      nil
    end
  end
end
