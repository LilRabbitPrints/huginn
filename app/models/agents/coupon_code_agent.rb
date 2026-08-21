module Agents
  class CouponCodeAgent < Agent
    include WebRequestConcern

    default_schedule "0 8 * * 1"

    description <<~MD
      The **CouponCodeAgent** creates a new time-limited Etsy discount code every Monday morning
      via the Etsy API, then emits a coupon event for downstream announcement agents.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `discount_pct` — percentage discount (default: 15)
      - `code_prefix` — prefix for coupon codes (default: BUNNY)
      - `valid_days` — how many days the coupon is valid (default: 7)
      - `min_order_amount` — minimum order value in listing currency (default: 0)
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits:

          {
            "event_type": "coupon_created",
            "coupon_code": "BUNNY15",
            "discount_pct": 15,
            "valid_until": "2026-01-07",
            "created_at": "..."
          }
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
        'discount_pct' => 15,
        'code_prefix' => 'BUNNY',
        'valid_days' => 7,
        'min_order_amount' => 0,
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

    def check
      code = generate_code
      valid_until = Date.today + interpolated['valid_days'].to_i

      result = create_etsy_coupon(code, valid_until)
      return unless result

      memory['current_coupon'] = { 'code' => code, 'discount_pct' => interpolated['discount_pct'].to_i, 'valid_until' => valid_until.to_s }
      save!

      create_event payload: {
        'event_type' => 'coupon_created',
        'coupon_code' => code,
        'discount_pct' => interpolated['discount_pct'].to_i,
        'valid_until' => valid_until.to_s,
        'min_order_amount' => interpolated['min_order_amount'].to_f,
        'created_at' => Time.now.utc.iso8601
      }
      log("Created coupon #{code} valid until #{valid_until}")
    end

    private

    def generate_code
      suffix = Date.today.strftime('%d%m')
      "#{interpolated['code_prefix']}#{interpolated['discount_pct']}#{suffix}"
    end

    def create_etsy_coupon(code, valid_until)
      body = {
        coupon_code: code,
        pct_discount: interpolated['discount_pct'].to_i,
        domestic_only: false,
        currency_code: 'GBP',
        min_order_subtotal_amount: interpolated['min_order_amount'].to_f,
        expiry_date: valid_until.to_time.to_i
      }.reject { |_, v| v.zero? }

      response = faraday.post(
        "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/coupons",
        body.to_json,
        { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}", 'Content-Type' => 'application/json' }
      )
      if response.success?
        JSON.parse(response.body)
      else
        error("CouponCodeAgent create error #{response.status}: #{response.body}")
        nil
      end
    rescue StandardError => e
      error("CouponCodeAgent error: #{e.message}")
      nil
    end
  end
end
