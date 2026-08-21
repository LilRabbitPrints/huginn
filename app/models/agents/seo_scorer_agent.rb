module Agents
  class SeoScorerAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **SeoScorerAgent** scores a listing brief against 10 Etsy SEO criteria (10 points each,
      max 100). If the score is below `min_score`, the event is routed to `low_score_output`
      (to loop back for re-optimisation). If it meets the threshold, it's forwarded to continue
      the pipeline.

      **Scoring criteria (10 pts each):**
      1. Title is 120–140 characters
      2. Title starts with primary keyword (first 3 words contain target keyword)
      3. All 13 tag slots are used
      4. At least 5 tags are long-tail (3+ words)
      5. Short description contains the keyword in the first 160 chars
      6. Long description is 300+ words
      7. "Personalised" or "custom" mentioned in title
      8. Bulk order pricing mentioned in long description
      9. Tags include at least one occasion/recipient tag
      10. No duplicate words across tags

      **Options:**
      - `primary_keyword` — keyword to check for front-loading (default: taken from first tag)
      - `min_score` — minimum score to pass downstream (default: 80)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `seo_score`, `seo_breakdown` (hash of criterion → score), and
      `seo_passed` (boolean) fields. Events with score < min_score include `needs_revision: true`.
    MD

    def default_options
      {
        'primary_keyword' => '',
        'min_score' => 80,
        'expected_receive_period_in_days' => 2
      }
    end

    def validate_options
      errors.add(:base, 'min_score must be 0–100') unless
        options['min_score'].to_i.between?(0, 100)
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        score, breakdown = score_listing(event.payload)
        passed = score >= interpolated['min_score'].to_i
        create_event payload: event.payload.merge(
          'seo_score' => score,
          'seo_breakdown' => breakdown,
          'seo_passed' => passed,
          'needs_revision' => !passed
        )
      end
    end

    private

    def score_listing(payload)
      title = (payload['optimized_title'] || payload['title']).to_s
      tags = payload['tags'] || []
      short_desc = payload['short_description'].to_s
      long_desc = payload['long_description'].to_s
      keyword = interpolated['primary_keyword'].presence || tags.first.to_s.downcase

      breakdown = {}

      breakdown['title_length'] = title.length.between?(120, 140) ? 10 : 0
      title_start = title.downcase.split(/[\s|,]+/).first(3).join(' ')
      breakdown['title_keyword_front'] = title_start.include?(keyword.downcase) ? 10 : 0
      breakdown['all_13_tags'] = tags.size == 13 ? 10 : [tags.size, 10].min
      long_tail = tags.count { |t| t.split.size >= 3 }
      breakdown['long_tail_tags'] = long_tail >= 5 ? 10 : (long_tail * 2)
      breakdown['short_desc_keyword'] = short_desc[0..159].downcase.include?(keyword.downcase) ? 10 : 0
      breakdown['long_desc_length'] = long_desc.split.size >= 300 ? 10 : 0
      personalised_in_title = title.downcase.match?(/personalise|personaliz|custom/)
      breakdown['personalisation_in_title'] = personalised_in_title ? 10 : 0
      breakdown['bulk_in_desc'] = long_desc.downcase.match?(/bulk|wholesale|corporate|team order/) ? 10 : 0
      occasion_tags = tags.count { |t| t.match?(/gift|birthday|wedding|easter|christmas|anniversary/) }
      breakdown['occasion_tag'] = occasion_tags >= 1 ? 10 : 0
      all_tag_words = tags.join(' ').split
      breakdown['no_duplicate_tag_words'] = all_tag_words.size == all_tag_words.uniq.size ? 10 : 5

      total = breakdown.values.sum
      [total, breakdown]
    end
  end
end
