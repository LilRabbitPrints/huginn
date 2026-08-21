module Agents
  class CouponPerformanceAgent < Agent
    include WebRequestConcern

    default_schedule "every_7d"

    description <<~MD
      The **CouponPerformanceAgent** tracks how many orders used the current week's coupon code
      and calculates its conversion rate. It reports performance to help you refine your
      coupon strategy over time.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits:

          {
            "event_type": "coupon_performance",
            "coupon_code": "BUNNY15",
            "orders_with_coupon": 7,
            "total_orders": 23,
            "conversion_rate_pct": 30.4,
            "total_discount_given": "£14.35",
            "week_of": "..."
          }
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
        'expected_update_period_in_days' => 8
      }
    end

    def validate_options
      errors.add(:base, 'shop_id is required') if options['shop_id'].blank?
      errors.add(:base, 'api_key is required') if options['api_key'].blank?
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        next unless event.payload['event_type'] == 'coupon_created'

        memory['tracking_coupon'] = event.payload
        save!
      end
    end

    def check
      coupon = memory['tracking_coupon']
      return unless coupon

      code = coupon['coupon_code']
      orders = fetch_recent_orders
      orders_with_coupon = orders.select { |o| o['discount_amount'].to_f.positive? }
      total_discount = orders_with_coupon.sum { |o| o['discount_amount'].to_f }
      conversion = orders.empty? ? 0 : (orders_with_coupon.size.to_f / orders.size * 100).round(1)

      create_event payload: {
        'event_type' => 'coupon_performance',
        'coupon_code' => code,
        'orders_with_coupon' => orders_with_coupon.size,
        'total_orders' => orders.size,
        'conversion_rate_pct' => conversion,
        'total_discount_given' => "£#{format('%.2f', total_discount)}",
        'week_of' => Date.today.to_s
      }
    end

    private

    def fetch_recent_orders
      since = (Time.now - 7 * 86_400).to_i
      response = faraday.get(
        "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/receipts",
        { min_created: since, limit: 100 },
        { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}" }
      )
      return [] unless response.success?

      JSON.parse(response.body)['results'] || []
    rescue StandardError => e
      error("CouponPerformanceAgent: #{e.message}")
      []
    end
  end
end
