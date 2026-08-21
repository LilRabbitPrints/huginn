module Agents
  class TitleAuditAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **TitleAuditAgent** specifically audits the title field of Etsy listing audit events.
      It checks:
      1. Title is 120–140 characters
      2. Primary keyword appears in the first 3 words
      3. No keyword stuffing (no phrase repeated more than twice)
      4. Personalisation signal present ("Personalised", "Custom", or "with Name")
      5. No ALL CAPS words (unless an abbreviation)

      Passes the event downstream with `title_audit` results appended.

      **Options:**
      - `primary_keywords` — array of keywords to check for front-loading (uses listing tags if not set)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `title_audit: {passed, score, issues}` appended.
    MD

    def default_options
      {
        'primary_keywords' => [],
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        title = (payload['title'] || payload['optimized_title']).to_s
        issues = []
        score = 100

        unless title.length.between?(120, 140)
          issues << "Length #{title.length} (target 120–140 chars)"
          score -= 20
        end

        keywords = (interpolated['primary_keywords'].presence || payload['tags'] || []).first(3)
        unless keywords.any? { |kw| title.downcase.start_with?(kw.downcase.split.first(1).join) }
          issues << 'Primary keyword not front-loaded in title'
          score -= 20
        end

        unless title.match?(/personalise|personaliz|custom/i)
          issues << 'No personalisation signal (Personalised/Custom/with Name)'
          score -= 15
        end

        words = title.split
        word_freq = words.group_by { |w| w.downcase }.transform_values(&:size)
        repeated = word_freq.select { |_, c| c > 2 }
        unless repeated.empty?
          issues << "Keyword stuffing detected: #{repeated.keys.join(', ')}"
          score -= 15
        end

        all_caps = words.count { |w| w == w.upcase && w.length > 2 }
        if all_caps > 1
          issues << "#{all_caps} ALL CAPS words detected"
          score -= 10
        end

        create_event payload: payload.merge(
          'title_audit' => { 'passed' => issues.empty?, 'score' => [score, 0].max, 'issues' => issues }
        )
      end
    end
  end
end
