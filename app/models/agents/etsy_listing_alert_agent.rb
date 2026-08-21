require 'net/smtp'

module Agents
  class EtsyListingAlertAgent < Agent
    include EmailConcern

    cannot_be_scheduled!

    description <<~MD
      The **EtsyListingAlertAgent** collects listing events throughout the day and sends a
      daily "revival queue" summary email listing all listings scheduled for revival.

      Attach this agent to the output of EtsyListingSchedulerAgent. It accumulates events
      until the configured `send_time` (UTC hour), then sends a digest email and clears its buffer.

      **Options:**
      - `recipients` — email address(es) to send the digest to
      - `send_time_utc_hour` — UTC hour (0–23) at which to send the daily digest (default: 8)
      - `subject` — email subject line (Liquid-interpolated)
      - `expected_receive_period_in_days` — for health check
    MD

    def default_options
      {
        'recipients' => [],
        'send_time_utc_hour' => 8,
        'subject' => 'Lil Rabbit Prints — Daily Revival Queue',
        'expected_receive_period_in_days' => 2
      }
    end

    def validate_options
      errors.add(:base, 'recipients must be an array or comma-separated string') if
        options['recipients'].blank?
      errors.add(:base, 'send_time_utc_hour must be 0–23') unless
        options['send_time_utc_hour'].to_i.between?(0, 23)
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      buffer = memory['buffer'] ||= []
      incoming_events.each { |e| buffer << e.payload }
      memory['buffer'] = buffer
      save!
      maybe_send_digest!
    end

    private

    def maybe_send_digest!
      last_sent = memory['last_sent_date']
      today = Date.today.to_s
      now_hour = Time.now.utc.hour
      threshold = interpolated['send_time_utc_hour'].to_i

      return if last_sent == today || now_hour < threshold

      buffer = memory['buffer'] || []
      return if buffer.empty?

      body = build_body(buffer)
      subject_line = interpolated['subject']
      recipient_list = recipients

      recipient_list.each do |recipient|
        SystemMailer.send_message(
          to: recipient,
          from: ENV['EMAIL_FROM_ADDRESS'],
          subject: subject_line,
          headline: "Today's Revival Queue (#{buffer.size} listings)",
          body: body,
          content_type: 'text/html',
          groups: []
        ).deliver_now
        log "Sent revival queue digest to #{recipient}"
      rescue StandardError => e
        error("Error sending digest to #{recipient}: #{e.message}")
      end

      memory['buffer'] = []
      memory['last_sent_date'] = today
      save!
    end

    def build_body(buffer)
      rows = buffer.map do |p|
        "<tr><td>#{p['listing_id']}</td><td>#{p['title']}</td>" \
          "<td>#{p['revival_score']}</td><td>#{p['views']}</td>" \
          "<td>#{p['num_favorers']}</td></tr>"
      end.join
      <<~HTML
        <table border="1" cellpadding="4" cellspacing="0">
          <thead><tr><th>ID</th><th>Title</th><th>Score</th><th>Views</th><th>Favourers</th></tr></thead>
          <tbody>#{rows}</tbody>
        </table>
      HTML
    end
  end
end
