module Agents
  class DescriptionAuditAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **DescriptionAuditAgent** audits the description field of Etsy listings for SEO
      compliance. It checks:
      1. Primary keyword appears in the first 160 characters
      2. "Personalised" or "custom" is mentioned
      3. Bulk order pricing or wholesale is mentioned
      4. Description is at least 300 words
      5. A call-to-action is present

      **Options:**
      - `primary_keyword` — keyword to check in first 160 chars (falls back to first tag)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `description_audit: {passed, score, issues}` appended.
    MD

    def default_options
      {
        'primary_keyword' => '',
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        desc = (payload['long_description'] || payload['description'] || '').to_s
        keyword = interpolated['primary_keyword'].presence ||
                  payload.dig('tags', 0).to_s.downcase ||
                  'rabbit print'
        issues = []
        score = 100

        unless desc[0..159].downcase.include?(keyword.downcase)
          issues << "Primary keyword '#{keyword}' not in first 160 chars"
          score -= 25
        end

        unless desc.match?(/personalise|personaliz|custom/i)
          issues << 'No personalisation mention in description'
          score -= 20
        end

        unless desc.match?(/bulk|wholesale|corporate|team order/i)
          issues << 'No bulk order mention'
          score -= 15
        end

        word_count = desc.split.size
        if word_count < 300
          issues << "Description only #{word_count} words (target 300+)"
          score -= 20
        end

        unless desc.match?(/message me|contact me|question|happy to help/i)
          issues << 'No CTA (call-to-action) detected'
          score -= 10
        end

        create_event payload: payload.merge(
          'description_audit' => { 'passed' => issues.empty?, 'score' => [score, 0].max, 'issues' => issues, 'word_count' => word_count }
        )
      end
    end
  end
end
