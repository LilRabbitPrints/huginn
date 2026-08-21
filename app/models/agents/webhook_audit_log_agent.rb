module Agents
  class WebhookAuditLogAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **WebhookAuditLogAgent** logs every webhook send and receive with timestamp, event type,
      payload hash (SHA256), and success/failure status. This provides a complete audit trail for
      debugging and compliance.

      It stores the log in memory (rolling window of `max_log_entries` entries) and emits
      a weekly audit summary event.

      **Options:**
      - `max_log_entries` — max entries to keep in memory (default: 1000)
      - `emit_weekly_summary` — emit a summary event every 7 days (default: true)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Re-emits the original event unchanged (pass-through), with audit metadata added.
      Periodically emits `{event_type: "webhook_audit_summary", ...}`.
    MD

    def default_options
      {
        'max_log_entries' => 1000,
        'emit_weekly_summary' => true,
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      audit_log = memory['audit_log'] ||= []
      incoming_events.each do |event|
        payload = event.payload
        entry = {
          'timestamp' => Time.now.utc.iso8601,
          'event_type' => payload['event_type'],
          'payload_hash' => Digest::SHA256.hexdigest(payload.to_json)[0..15],
          'success' => payload['success'],
          'listing_id' => payload['listing_id']
        }.compact
        audit_log << entry
        create_event payload: payload.merge('audit_entry' => entry)
      end

      audit_log = audit_log.last(interpolated['max_log_entries'].to_i)
      memory['audit_log'] = audit_log
      maybe_emit_summary!(audit_log)
      save!
    end

    private

    def maybe_emit_summary!(log)
      return unless boolify(interpolated['emit_weekly_summary'])

      last_summary = memory['last_summary_date']
      today = Date.today.to_s
      return if last_summary == today || Date.today.wday != 1

      success_count = log.count { |e| e['success'] }
      fail_count = log.size - success_count
      create_event payload: {
        'event_type' => 'webhook_audit_summary',
        'total_events' => log.size,
        'success_count' => success_count,
        'failure_count' => fail_count,
        'success_rate_pct' => log.empty? ? 0 : (success_count.to_f / log.size * 100).round(1),
        'week_of' => today
      }
      memory['last_summary_date'] = today
    end
  end
end
