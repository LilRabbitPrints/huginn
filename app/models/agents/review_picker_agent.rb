module Agents
  class ReviewPickerAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **ReviewPickerAgent** selects the single best review from a pool of incoming review
      events to use as the social proof image for a specific listing.

      Scoring criteria (each worth 1 point):
      - Mentions "personalised" or "custom"
      - Mentions product quality ("beautiful", "gorgeous", "amazing", "perfect")
      - Mentions fast shipping ("fast", "quick", "arrived quickly", "next day")
      - Review is 40+ characters (substantial)
      - Has a named reviewer (not anonymous)

      **Options:**
      - `selection_keywords` — array of high-value keywords to score reviews by
      - `min_review_length` — minimum character count (default: 40)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits the highest-scoring review event with a `selection_score` field added.
    MD

    def default_options
      {
        'selection_keywords' => %w[personalised custom beautiful gorgeous amazing perfect fast quick],
        'min_review_length' => 40,
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      candidates = incoming_events.map do |event|
        [score_review(event.payload), event.payload]
      end
      best_score, best_review = candidates.max_by { |s, _| s }
      return unless best_review

      create_event payload: best_review.merge('selection_score' => best_score)
    end

    private

    def score_review(payload)
      text = payload['review'].to_s.downcase
      keywords = interpolated['selection_keywords'] || []
      score = keywords.sum { |kw| text.include?(kw.downcase) ? 1 : 0 }
      score += 1 if text.length >= interpolated['min_review_length'].to_i
      score += 1 if payload['buyer_name'].present? && payload['buyer_name'] != 'Verified Buyer'
      score
    end
  end
end
