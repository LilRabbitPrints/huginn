module Agents
  class ReviewFormatterAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **ReviewFormatterAgent** formats the selected review into a render-ready spec for the
      social proof image (slot 7). It truncates the review text to fit the image template,
      anonymises the reviewer name to first name + last initial, and adds brand styling.

      **Options:**
      - `max_review_chars` — max characters of review text to show (default: 120)
      - `star_color` — hex color for star rating icons (default: `#ffd700`)
      - `card_background` — hex color for the review card (default: `#f9f0e8`)
      - `text_color` — hex color for review text (default: `#2d1b0e`)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `formatted_review` spec ready for mockup generator rendering.
    MD

    def default_options
      {
        'max_review_chars' => 120,
        'star_color' => '#ffd700',
        'card_background' => '#f9f0e8',
        'text_color' => '#2d1b0e',
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        review_text = payload['review'].to_s.truncate(interpolated['max_review_chars'].to_i)
        reviewer = anonymise_name(payload['buyer_name'])
        formatted_review = {
          'review_text' => "\"#{review_text}\"",
          'reviewer' => reviewer,
          'star_rating' => payload['rating'].to_i,
          'star_color' => interpolated['star_color'],
          'card_background' => interpolated['card_background'],
          'text_color' => interpolated['text_color'],
          'verified_badge' => true,
          'shop_logo' => true
        }
        create_event payload: payload.merge('formatted_review' => formatted_review)
      end
    end

    private

    def anonymise_name(name)
      return 'Happy Customer' if name.blank? || name == 'Verified Buyer'

      parts = name.to_s.split
      return name if parts.size == 1

      "#{parts.first} #{parts.last[0]}."
    end
  end
end
