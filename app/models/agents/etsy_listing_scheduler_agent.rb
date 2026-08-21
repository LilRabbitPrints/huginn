module Agents
  class EtsyListingSchedulerAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **EtsyListingSchedulerAgent** throttles how many listings enter the revival pipeline
      per day. It buffers incoming listing events and only releases up to `max_per_day` of them
      per 24-hour window, forwarding the highest `revival_score` listings first.

      **Options:**
      - `max_per_day` — maximum listings to release into the pipeline per 24h window (default: 5)
      - `sort_by` — field to sort buffered listings by before releasing (default: `revival_score`)
      - `sort_direction` — `desc` (default) or `asc`
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Re-emits the original listing payload with an added `scheduled_at` timestamp.
    MD

    def default_options
      {
        'max_per_day' => 5,
        'sort_by' => 'revival_score',
        'sort_direction' => 'desc',
        'expected_receive_period_in_days' => 2
      }
    end

    def validate_options
      errors.add(:base, 'max_per_day must be a positive integer') unless
        options['max_per_day'].to_s =~ /\A[1-9]\d*\z/
      errors.add(:base, 'sort_direction must be asc or desc') unless
        %w[asc desc].include?(options['sort_direction'])
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      queue = memory['queue'] ||= []
      incoming_events.each { |e| queue << e.payload }
      sort_queue!(queue)
      memory['queue'] = queue
      save!
      release_due!
    end

    private

    def released_today
      memory['released_today'] ||= { 'date' => Date.today.to_s, 'count' => 0 }
      rd = memory['released_today']
      if rd['date'] != Date.today.to_s
        rd['date'] = Date.today.to_s
        rd['count'] = 0
        memory['released_today'] = rd
        save!
      end
      rd
    end

    def release_due!
      rd = released_today
      max = interpolated['max_per_day'].to_i
      available = max - rd['count']
      return if available <= 0

      queue = memory['queue'] ||= []
      to_release = queue.shift([available, queue.size].min)
      to_release.each do |payload|
        create_event payload: payload.merge('scheduled_at' => Time.now.utc.iso8601)
        rd['count'] += 1
      end
      memory['queue'] = queue
      memory['released_today'] = rd
      save!
    end

    def sort_queue!(queue)
      field = interpolated['sort_by']
      dir = interpolated['sort_direction']
      queue.sort_by! { |p| p[field].to_f }
      queue.reverse! if dir == 'desc'
    end
  end
end
