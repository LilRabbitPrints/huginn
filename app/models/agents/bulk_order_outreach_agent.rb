module Agents
  class BulkOrderOutreachAgent < Agent
    include WebRequestConcern

    default_schedule "every_2h"

    description <<~MD
      The **BulkOrderOutreachAgent** monitors your Etsy conversations for bulk/wholesale
      inquiries by polling the Etsy conversations API and looking for key terms.
      When a bulk inquiry is detected, it emits an event for the quote drafter.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `bulk_keywords` — keywords indicating bulk interest
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits:

          {
            "event_type": "bulk_inquiry_detected",
            "conversation_id": ...,
            "buyer_name": "...",
            "message_preview": "...",
            "detected_keywords": ["bulk", "100"],
            "message_timestamp": ...
          }
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
        'bulk_keywords' => %w[bulk wholesale corporate team school church 50 100 200 order quantity],
        'expected_update_period_in_days' => 1
      }
    end

    def validate_options
      errors.add(:base, 'shop_id is required') if options['shop_id'].blank?
      errors.add(:base, 'api_key is required') if options['api_key'].blank?
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def check
      conversations = fetch_recent_conversations
      seen = memory['seen_conversation_ids'] ||= []
      keywords = interpolated['bulk_keywords'] || []

      conversations.each do |conv|
        conv_id = conv['conversation_id'].to_s
        next if seen.include?(conv_id)

        messages = conv['messages'] || []
        last_message = messages.last || {}
        text = last_message['message_body'].to_s.downcase
        detected = keywords.select { |kw| text.include?(kw.downcase) }
        next unless detected.any?

        create_event payload: {
          'event_type' => 'bulk_inquiry_detected',
          'conversation_id' => conv_id,
          'buyer_name' => conv.dig('other_user', 'login_name') || 'Unknown Buyer',
          'message_preview' => text.truncate(200),
          'detected_keywords' => detected,
          'message_timestamp' => last_message['creation_timestamp']
        }
        seen << conv_id
      end

      memory['seen_conversation_ids'] = seen.last(500)
      save!
    end

    private

    def fetch_recent_conversations
      response = faraday.get(
        "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/conversations",
        { limit: 50 },
        { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}" }
      )
      return [] unless response.success?

      JSON.parse(response.body)['results'] || []
    rescue StandardError => e
      error("BulkOrderOutreachAgent: #{e.message}")
      []
    end
  end
end
