module Agents
  class CouponExpiryReminderAgent < Agent
    default_schedule "0 9 * * 5"

    description <<~MD
      The **CouponExpiryReminderAgent** runs every Friday at 9am and checks if there's a
      current active coupon that expires this Sunday. If so, it emits a "last chance" reminder
      event for the SalePostingOrchestratorAgent to broadcast.

      **Options:**
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits `{event_type: "coupon_expiry_reminder", coupon_code: ..., expires: ..., social_copy: {...}}`.
    MD

    def default_options
      {
        'expected_update_period_in_days' => 8
      }
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        next unless event.payload['event_type'] == 'coupon_created'

        memory['current_coupon'] = event.payload
        save!
      end
    end

    def check
      coupon = memory['current_coupon']
      return unless coupon

      expires = Date.parse(coupon['valid_until']) rescue nil
      return unless expires

      days_until_expiry = (expires - Date.today).to_i
      return unless days_until_expiry.between?(0, 3)

      code = coupon['coupon_code']
      pct = coupon['discount_pct']
      urgency = days_until_expiry.zero? ? 'TODAY ONLY!' : "expires #{expires.strftime('%A')}!"

      twitter = "🐇 Last chance! #{pct}% off at Lil Rabbit Prints — code #{code} #{urgency} Shop personalised rabbit prints now 👉 https://www.etsy.com/shop/LilRabbitPrints"
      threads = "Hey rabbit lovers 🐇 Just a reminder that your #{pct}% off discount code #{code} #{urgency} Don't miss out on a gorgeous personalised print! ✨ https://www.etsy.com/shop/LilRabbitPrints"

      create_event payload: {
        'event_type' => 'coupon_expiry_reminder',
        'coupon_code' => code,
        'discount_pct' => pct,
        'expires' => expires.to_s,
        'days_until_expiry' => days_until_expiry,
        'social_copy' => { 'twitter' => twitter, 'threads' => threads }
      }
      log("CouponExpiryReminderAgent fired reminder for #{code}")
    end
  end
end
