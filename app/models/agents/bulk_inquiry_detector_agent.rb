module Agents
  class BulkInquiryDetectorAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **BulkInquiryDetectorAgent** is a targeted sub-agent that receives raw conversation
      events and applies a more sophisticated keyword and pattern matching to confirm bulk/
      wholesale intent. It filters out false positives (e.g., mentions of "100%" as in
      "100% cotton" rather than "order 100 items").

      **Options:**
      - `bulk_keywords` — high-signal keywords for bulk intent
      - `false_positive_patterns` — regex patterns that, if matched, indicate NOT a bulk order
      - `min_keyword_confidence` — minimum matching keywords to confirm intent (default: 1)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits confirmed bulk inquiry events (same structure as BulkOrderOutreachAgent) with
      an added `confidence_score` field.
    MD

    def default_options
      {
        'bulk_keywords' => %w[bulk wholesale corporate team school office staff wedding graduation],
        'false_positive_patterns' => ['100% cotton', '100% natural', 'star rating', 'five star'],
        'min_keyword_confidence' => 1,
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        text = payload['message_preview'].to_s.downcase
        keywords = interpolated['bulk_keywords'] || []
        false_patterns = interpolated['false_positive_patterns'] || []
        next if false_patterns.any? { |p| text.include?(p.downcase) }

        detected = keywords.select { |kw| text.include?(kw.downcase) }
        confidence = detected.size
        next if confidence < interpolated['min_keyword_confidence'].to_i

        create_event payload: payload.merge(
          'confirmed_bulk_intent' => true,
          'confidence_score' => confidence,
          'confirmed_keywords' => detected
        )
      end
    end
  end
end
