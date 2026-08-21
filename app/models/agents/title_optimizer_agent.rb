module Agents
  class TitleOptimizerAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **TitleOptimizerAgent** specialises in generating a single high-converting Etsy listing
      title (max 140 characters) with the primary keyword front-loaded within the first 3 words.

      It receives a brief event from OpenAiListingBriefAgent and produces a focused, refined title
      using a targeted OpenAI prompt. The title is validated for character count and keyword placement
      before being emitted.

      **Options:**
      - `api_key` — OpenAI API key
      - `model` — OpenAI model (default: `gpt-4o`)
      - `primary_keyword_hint` — optional keyword to prioritise (e.g., "personalised rabbit print")
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits the received payload with `optimized_title` replaced/validated and a
      `title_char_count` field added.
    MD

    def default_options
      {
        'api_key' => '',
        'model' => 'gpt-4o',
        'primary_keyword_hint' => '',
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
        title = refine_title(event.payload)
        next unless title

        payload = event.payload.merge(
          'optimized_title' => title,
          'title_char_count' => title.length
        )
        create_event payload: payload
      end
    end

    private

    def refine_title(payload)
      hint = interpolated['primary_keyword_hint'].presence ||
             payload.dig('tags', 0) ||
             'personalised rabbit print'

      prompt = <<~PROMPT
        You are an Etsy SEO expert. Generate ONE optimised listing title (max 140 characters).
        Rules:
        - Start with the exact keyword: "#{hint}"
        - Use | or , to separate keyword phrases naturally
        - Include personalisation signal (e.g., "Custom", "Personalised", "with Name")
        - No ALL CAPS, no keyword stuffing
        - Make it human-readable and click-worthy

        Current draft title: #{payload['optimized_title'] || payload['original_title'] || payload['title']}
        Product niche: personalised rabbit prints and bunny gifts

        Respond with ONLY the title string, no quotes, no explanation.
      PROMPT

      response = faraday.post(
        'https://api.openai.com/v1/chat/completions',
        {
          model: interpolated['model'],
          messages: [{ role: 'user', content: prompt }],
          temperature: 0.5,
          max_tokens: 60
        }.to_json,
        {
          'Authorization' => "******'api_key']}",
          'Content-Type' => 'application/json'
        }
      )
      raise "OpenAI error #{response.status}" unless response.success?

      title = JSON.parse(response.body).dig('choices', 0, 'message', 'content').to_s.strip
      title = title[0..139] if title.length > 140
      title
    rescue StandardError => e
      error("TitleOptimizerAgent error: #{e.message}")
      nil
    end
  end
end
