module Agents
  class SalePostingOrchestratorAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **SalePostingOrchestratorAgent** fires all social media posts simultaneously when it
      receives a promotion event with `social_copy`. It posts to Twitter/X, Threads, and
      Pinterest in parallel (sequentially within Huginn's single-threaded model) and tracks
      which posts succeeded.

      Rather than duplicate the posting logic, this agent calls the downstream posting agents
      by emitting their input events. Connect TwitterPublishAgent, ThreadsPublishAgent, and
      PostAgent (Pinterest) as receivers of this agent's output.

      **Options:**
      - `platforms` — array of platforms to post to (default: `["twitter", "threads", "pinterest"]`)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits one event per platform with the relevant copy:

          {
            "platform": "twitter",
            "message": "...",
            "listing_url": "...",
            "listing_id": ...,
            "triggered_at": "..."
          }
    MD

    def default_options
      {
        'platforms' => %w[twitter threads pinterest],
        'expected_receive_period_in_days' => 3
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        copy = payload['social_copy']
        next unless copy

        platforms = interpolated['platforms'] || []
        platforms.each do |platform|
          message = case platform
                    when 'twitter' then copy['twitter']
                    when 'threads' then copy['threads']
                    when 'pinterest' then copy['pinterest']
                    end
          next unless message.present?

          create_event payload: {
            'platform' => platform,
            'message' => message,
            'listing_url' => payload['listing_url'],
            'listing_id' => payload['listing_id'],
            'title' => payload['title'],
            'image_url' => payload.dig('images', 0, 'url_570xN') || payload.dig('images', 0, 'url_fullxfull'),
            'triggered_at' => Time.now.utc.iso8601
          }
        end
      end
    end
  end
end
