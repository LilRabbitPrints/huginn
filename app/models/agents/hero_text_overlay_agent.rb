module Agents
  class HeroTextOverlayAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **HeroTextOverlayAgent** generates the text overlay for slot 1 (hero image). It creates
      a punchy, keyword-rich short phrase suitable for overlaying on a lifestyle photo.

      Rules:
      - Max 60 characters
      - Contains the primary keyword
      - Human-readable, not robotic
      - Optionally includes a secondary CTA ("Personalise Yours →")

      Uses OpenAI to generate the overlay if `use_ai` is true, otherwise derives it from the title.

      **Options:**
      - `api_key` — OpenAI API key (required if `use_ai` is true)
      - `use_ai` — use OpenAI to craft the overlay (default: true)
      - `include_cta` — append a CTA phrase (default: true)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `hero_text_overlay` (max 60 chars) and `hero_cta` fields.
    MD

    def default_options
      {
        'api_key' => '',
        'use_ai' => true,
        'include_cta' => true,
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        overlay = boolify(interpolated['use_ai']) ? ai_overlay(payload) : simple_overlay(payload)
        cta = boolify(interpolated['include_cta']) ? 'Personalise Yours →' : nil
        create_event payload: payload.merge('hero_text_overlay' => overlay, 'hero_cta' => cta)
      end
    end

    private

    def ai_overlay(payload)
      keyword = payload.dig('tags', 0) || 'personalised rabbit print'
      title = payload['optimized_title'] || payload['title']
      prompt = "Create a 1-line image overlay text (max 60 chars) for an Etsy product hero image. " \
               "Product: #{title}. Primary keyword: #{keyword}. Be warm, human, clickable. " \
               "Do NOT start with 'Introducing'. Output ONLY the overlay text, no quotes."

      response = faraday.post(
        'https://api.openai.com/v1/chat/completions',
        { model: 'gpt-4o-mini', messages: [{ role: 'user', content: prompt }], max_tokens: 30 }.to_json,
        { 'Authorization' => "******'api_key']}", 'Content-Type' => 'application/json' }
      )
      return simple_overlay(payload) unless response.success?

      JSON.parse(response.body).dig('choices', 0, 'message', 'content').to_s.strip[0..59]
    rescue StandardError
      simple_overlay(payload)
    end

    def simple_overlay(payload)
      ((payload['optimized_title'] || payload['title']).to_s.split(' ').first(6).join(' '))[0..59]
    end
  end
end
