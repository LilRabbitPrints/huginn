module Agents
  class BulkFollowUpAgent < Agent
    default_schedule "every_6h"

    description <<~MD
      The **BulkFollowUpAgent** monitors bulk inquiries that haven't received a reply within
      `follow_up_hours` hours and drafts a gentle follow-up message for your approval.

      It tracks conversation IDs where a quote was sent (via events from BulkQuoteDrafterAgent)
      and flags any that are still awaiting a buyer response after the timeout.

      **Options:**
      - `follow_up_hours` — hours to wait before suggesting follow-up (default: 48)
      - `max_follow_ups` — max follow-up attempts per conversation (default: 2)
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "bulk_follow_up_draft", conversation_id: ..., follow_up_text: ..., attempt: N}`.
    MD

    def default_options
      {
        'follow_up_hours' => 48,
        'max_follow_ups' => 2,
        'expected_update_period_in_days' => 3
      }
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        conv_id = payload['conversation_id'].to_s
        case payload['event_type']
        when 'bulk_quote_draft'
          pending = memory['pending'] ||= {}
          pending[conv_id] = {
            'conversation_id' => conv_id,
            'buyer_name' => payload['buyer_name'],
            'sent_at' => Time.now.to_i,
            'follow_up_count' => 0
          }
          memory['pending'] = pending
          save!
        when 'bulk_inquiry_closed'
          pending = memory['pending'] ||= {}
          pending.delete(conv_id)
          memory['pending'] = pending
          save!
        end
      end
    end

    def check
      pending = memory['pending'] ||= {}
      threshold_seconds = interpolated['follow_up_hours'].to_f * 3600
      max_fu = interpolated['max_follow_ups'].to_i
      to_remove = []

      pending.each do |conv_id, record|
        age = Time.now.to_i - record['sent_at'].to_i
        next if age < threshold_seconds

        count = record['follow_up_count'].to_i
        if count >= max_fu
          to_remove << conv_id
          next
        end

        follow_up_text = draft_follow_up(record, count + 1)
        create_event payload: {
          'event_type' => 'bulk_follow_up_draft',
          'conversation_id' => conv_id,
          'buyer_name' => record['buyer_name'],
          'follow_up_text' => follow_up_text,
          'attempt' => count + 1
        }

        record['follow_up_count'] = count + 1
        record['sent_at'] = Time.now.to_i
      end

      to_remove.each { |id| pending.delete(id) }
      memory['pending'] = pending
      save!
    end

    private

    def draft_follow_up(record, attempt)
      name = record['buyer_name']
      if attempt == 1
        "Hi #{name}! 🐇 Just following up on my bulk order quote — I'd love to help create something special for your team/event. Any questions about designs or personalisation? Happy to chat!"
      else
        "Hi #{name}! Quick last check-in on your bulk print enquiry — if the timing isn't right just now, no worries at all. Just save this conversation and reach out whenever you're ready. 🐇"
      end
    end
  end
end
