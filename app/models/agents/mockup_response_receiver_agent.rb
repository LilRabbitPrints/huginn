module Agents
  class MockupResponseReceiverAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **MockupResponseReceiverAgent** is a pass-through agent that receives completed mockup
      payloads POSTed back from your external mockup generator application (via a Huginn
      WebhookAgent upstream) and enriches the event with normalised `mockup_images` array.

      It validates that all 7 carousel slots have image URLs before forwarding. Incomplete
      batches are held in memory until the missing slots arrive (or `slot_wait_minutes` elapses).

      **Options:**
      - `slot_wait_minutes` — how long to wait for all 7 slots before forwarding partial (default: 30)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `mockup_images` (array of 7 objects: `{slot, url, width, height}`),
      `mockup_complete` (boolean), and all original listing brief fields.
    MD

    def default_options
      {
        'slot_wait_minutes' => 30,
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        listing_id = payload['listing_id'].to_s
        images = normalize_images(payload['images'] || payload['mockup_images'] || [])

        buffer = memory['buffers'] ||= {}
        buffer[listing_id] ||= { 'images' => [], 'first_received' => Time.now.to_i, 'payload' => payload.except('images', 'mockup_images') }
        buffer[listing_id]['images'] = (buffer[listing_id]['images'] + images).uniq { |i| i['slot'] }
        memory['buffers'] = buffer
        save!

        all_slots = buffer[listing_id]['images'].map { |i| i['slot'] }.sort
        complete = (1..7).to_a == all_slots

        age_minutes = (Time.now.to_i - buffer[listing_id]['first_received'].to_i) / 60.0
        timed_out = age_minutes >= interpolated['slot_wait_minutes'].to_f

        next unless complete || timed_out

        emit_payload = buffer[listing_id]['payload'].merge(
          'mockup_images' => buffer[listing_id]['images'].sort_by { |i| i['slot'] },
          'mockup_complete' => complete
        )
        create_event payload: emit_payload
        buffer.delete(listing_id)
        memory['buffers'] = buffer
        save!
      end
    end

    private

    def normalize_images(images)
      images.map do |img|
        {
          'slot' => img['slot'].to_i,
          'url' => img['url'] || img['image_url'] || img['src'],
          'width' => img['width']&.to_i,
          'height' => img['height']&.to_i
        }
      end.select { |i| i['url'].present? && i['slot'].positive? }
    end
  end
end
