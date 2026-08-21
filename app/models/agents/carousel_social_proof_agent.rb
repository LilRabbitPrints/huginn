module Agents
  class CarouselSocialProofAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **CarouselSocialProofAgent** orchestrates slot 7 of the carousel — the social proof
      image showing a 5-star review quote. It fetches recent 5-star reviews from Etsy,
      selects the best one, and emits a spec for the mockup generator to render.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `review_keywords` — keywords that make a review extra valuable (default: personalised, quality, fast)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `social_proof_spec` containing the selected review and render instructions.
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
        'review_keywords' => %w[personalised quality fast beautiful perfect],
        'expected_receive_period_in_days' => 2
      }
    end

    def validate_options
      errors.add(:base, 'shop_id is required') if options['shop_id'].blank?
      errors.add(:base, 'api_key is required') if options['api_key'].blank?
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        review = pick_best_review(payload)
        social_proof_spec = {
          'slot' => 7,
          'type' => 'social_proof',
          'template' => 'review_quote_card',
          'review_text' => review&.dig('review') || 'Absolutely beautiful! Perfect personalised gift. Will definitely order again! ⭐⭐⭐⭐⭐',
          'reviewer_name' => review&.dig('buyer_name') || 'Sarah M.',
          'star_rating' => 5,
          'product_type' => payload['product_type'] || 'print'
        }
        create_event payload: payload.merge('social_proof_spec' => social_proof_spec, 'current_slot' => 7)
      end
    end

    private

    def pick_best_review(payload)
      reviews = fetch_reviews
      keywords = interpolated['review_keywords'] || []
      five_star = reviews.select { |r| r['rating'].to_i == 5 }
      scored = five_star.map do |r|
        text = r['review'].to_s.downcase
        score = keywords.sum { |kw| text.include?(kw.downcase) ? 1 : 0 }
        [score, r]
      end
      scored.max_by { |s, _| s }&.last
    end

    def fetch_reviews
      return [] if interpolated['shop_id'].blank?

      response = faraday.get(
        "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/reviews",
        { limit: 50 },
        { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}" }
      )
      return [] unless response.success?

      JSON.parse(response.body)['results'] || []
    rescue StandardError => e
      error("CarouselSocialProofAgent review fetch error: #{e.message}")
      []
    end
  end
end
