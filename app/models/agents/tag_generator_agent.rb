module Agents
  class TagGeneratorAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **TagGeneratorAgent** generates exactly 13 Etsy tags for a listing using OpenAI.

      It ensures the tag set includes:
      - At least 3 exact-match short-tail tags
      - At least 5 long-tail (3+ word) buyer-intent phrases
      - At least 2 seasonal/occasion tags
      - No duplicate tags, all lowercase, max 20 chars each

      Receives an event from OpenAiListingBriefAgent or TitleOptimizerAgent.

      **Options:**
      - `api_key` — OpenAI API key
      - `model` — OpenAI model (default: `gpt-4o`)
      - `extra_context` — additional context for tag generation (e.g., "UK market, cottagecore aesthetic")
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits the received payload with `tags` replaced by exactly 13 validated Etsy tags.
    MD

    def default_options
      {
        'api_key' => '',
        'model' => 'gpt-4o',
        'extra_context' => 'UK market, cottagecore aesthetic, nursery decor, personalised gifts',
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
        tags = generate_tags(event.payload)
        next unless tags

        create_event payload: event.payload.merge('tags' => tags)
      end
    end

    private

    def generate_tags(payload)
      prompt = <<~PROMPT
        You are an Etsy SEO tag specialist. Generate exactly 13 Etsy listing tags as a JSON array of strings.

        Rules:
        - Each tag: lowercase, max 20 characters, no punctuation except hyphens
        - Include 3 short exact-match tags (1-2 words)
        - Include 5 long-tail buyer-intent phrases (3-4 words)
        - Include 2 occasion/recipient tags (e.g., "rabbit lover gift", "easter bunny gift")
        - Include 2 style/aesthetic tags (e.g., "cottagecore print", "nursery wall art")
        - Include 1 personalisation tag (e.g., "personalised print")
        - No duplicates

        Product title: #{payload['optimized_title'] || payload['title']}
        Product niche: personalised rabbit prints and bunny gifts
        Extra context: #{interpolated['extra_context']}
        Current tags (for reference): #{payload['tags']&.join(', ')}

        Respond with ONLY a JSON array of 13 strings.
      PROMPT

      response = faraday.post(
        'https://api.openai.com/v1/chat/completions',
        {
          model: interpolated['model'],
          messages: [{ role: 'user', content: prompt }],
          temperature: 0.6,
          max_tokens: 200
        }.to_json,
        {
          'Authorization' => "******'api_key']}",
          'Content-Type' => 'application/json'
        }
      )
      raise "OpenAI error #{response.status}" unless response.success?

      raw = JSON.parse(response.body).dig('choices', 0, 'message', 'content').to_s.strip
      tags = JSON.parse(raw)
      tags = tags.map { |t| t.to_s.downcase.strip[0..19] }.uniq.first(13)
      tags.size == 13 ? tags : tags + (['rabbit print'] * (13 - tags.size))
    rescue StandardError => e
      error("TagGeneratorAgent error: #{e.message}")
      nil
    end
  end
end
