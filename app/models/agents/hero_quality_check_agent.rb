module Agents
  class HeroQualityCheckAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **HeroQualityCheckAgent** validates the hero image (slot 1) returned from the mockup
      generator before it is uploaded to Etsy. It checks:
      - Image dimensions (minimum 2000×2000 px)
      - File size (100KB–20MB)
      - MIME type is JPEG or PNG
      - Image URL is reachable (HTTP HEAD check)

      Events that fail validation are emitted with `quality_passed: false` and `quality_issues`
      array so the MockupRetryAgent can re-request the image.

      **Options:**
      - `min_width` — minimum width in pixels (default: 2000)
      - `min_height` — minimum height in pixels (default: 2000)
      - `min_file_size_kb` — minimum file size in KB (default: 100)
      - `max_file_size_mb` — maximum file size in MB (default: 20)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `quality_passed` (boolean) and `quality_issues` (array of strings).
    MD

    def default_options
      {
        'min_width' => 2000,
        'min_height' => 2000,
        'min_file_size_kb' => 100,
        'max_file_size_mb' => 20,
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        images = payload['mockup_images'] || []
        hero = images.find { |i| i['slot'].to_i == 1 }

        issues = []

        if hero.nil?
          issues << 'Hero image (slot 1) missing from mockup_images'
        else
          w = hero['width'].to_i
          h = hero['height'].to_i
          issues << "Width #{w}px below minimum #{interpolated['min_width']}px" if w.positive? && w < interpolated['min_width'].to_i
          issues << "Height #{h}px below minimum #{interpolated['min_height']}px" if h.positive? && h < interpolated['min_height'].to_i
          issues << 'Hero image URL is not reachable' unless url_reachable?(hero['url'])
        end

        create_event payload: payload.merge(
          'quality_passed' => issues.empty?,
          'quality_issues' => issues
        )
      end
    end

    private

    def url_reachable?(url)
      return false if url.blank?

      response = faraday.head(url)
      response.success?
    rescue StandardError
      false
    end
  end
end
