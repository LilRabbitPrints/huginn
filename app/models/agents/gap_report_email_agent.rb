require 'net/smtp'

module Agents
  class GapReportEmailAgent < Agent
    include EmailConcern

    cannot_be_scheduled!

    description <<~MD
      The **GapReportEmailAgent** receives gap analysis and tag swap suggestion events, collects
      them throughout the week, and delivers a formatted Monday morning SEO gap report email.

      The email includes:
      - Your current tag coverage summary
      - Top 20 keywords you're missing (with opportunity scores)
      - Per-listing tag swap recommendations
      - Quick action checklist

      **Options:**
      - `recipients` — email address(es) to send the report to
      - `send_day` — day of week to send (0=Sunday, 1=Monday, default: 1)
      - `send_hour_utc` — UTC hour to send (default: 7)
      - `expected_receive_period_in_days` — for health check
    MD

    def default_options
      {
        'recipients' => [],
        'send_day' => 1,
        'send_hour_utc' => 7,
        'expected_receive_period_in_days' => 8
      }
    end

    def validate_options
      errors.add(:base, 'recipients must be provided') if options['recipients'].blank?
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      buffer = memory['buffer'] ||= []
      incoming_events.each { |e| buffer << e.payload }
      memory['buffer'] = buffer
      save!
      maybe_send_report!
    end

    private

    def maybe_send_report!
      today = Date.today
      now = Time.now.utc
      last_sent = memory['last_sent']
      return if last_sent == today.to_s
      return unless now.wday == interpolated['send_day'].to_i && now.hour >= interpolated['send_hour_utc'].to_i

      buffer = memory['buffer'] || []
      return if buffer.empty?

      body = build_report_html(buffer)
      recipients.each do |recipient|
        SystemMailer.send_message(
          to: recipient,
          from: ENV['EMAIL_FROM_ADDRESS'],
          subject: "🐇 Lil Rabbit Prints — Weekly SEO Gap Report (#{today.strftime('%d %b %Y')})",
          headline: nil,
          body: body,
          content_type: 'text/html',
          groups: []
        ).deliver_now
        log("Sent SEO gap report to #{recipient}")
      rescue StandardError => e
        error("GapReportEmailAgent error: #{e.message}")
      end
      memory['buffer'] = []
      memory['last_sent'] = today.to_s
      save!
    end

    def build_report_html(buffer)
      gap_events = buffer.select { |p| p['event_type'] == 'gap_analysis' }
      swap_events = buffer.select { |p| p['event_type'] == 'tag_swap_suggestions' }
      top_gaps = gap_events.flat_map { |e| e['top_gaps'] || [] }.uniq { |g| g['keyword'] }.first(20)
      gap_rows = top_gaps.map { |g| "<tr><td>#{g['keyword']}</td><td>#{g['score']}</td></tr>" }.join
      swap_rows = swap_events.map do |e|
        swaps = (e['swaps'] || []).map { |s| "Remove <em>#{s['remove']}</em> → Add <strong>#{s['add']}</strong>" }.join('<br>')
        "<tr><td>#{e['listing_title']&.truncate(50)}</td><td>#{swaps}</td></tr>"
      end.join

      <<~HTML
        <h2>🐇 Weekly SEO Gap Report</h2>
        <h3>Top Missing Keywords</h3>
        <table border="1" cellpadding="4"><thead><tr><th>Keyword</th><th>Opportunity Score</th></tr></thead>
        <tbody>#{gap_rows}</tbody></table>
        <h3>Tag Swap Recommendations</h3>
        <table border="1" cellpadding="4"><thead><tr><th>Listing</th><th>Suggested Swaps</th></tr></thead>
        <tbody>#{swap_rows}</tbody></table>
      HTML
    end
  end
end
