module Agents
  class ListingSeoAuditAgent < Agent
    include WebRequestConcern

    default_schedule "every_7d"

    description <<~MD
      The **ListingSeoAuditAgent** audits all your active Etsy listings against SEO best
      practices and emits per-listing audit events. Listings that fail are flagged for
      re-entry into the revival pipeline.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `pass_threshold` — minimum score (0–100) to consider a listing passing audit (default: 70)
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits one audit event per listing:

          {
            "event_type": "listing_seo_audit",
            "listing_id": ...,
            "title": "...",
            "audit_score": 80,
            "audit_passed": true,
            "failures": []
          }
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
        'pass_threshold' => 70,
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
      listings = fetch_listings
      threshold = interpolated['pass_threshold'].to_i
      listings.each do |listing|
        score, failures = audit_listing(listing)
        create_event payload: {
          'event_type' => 'listing_seo_audit',
          'listing_id' => listing['listing_id'],
          'title' => listing['title'],
          'audit_score' => score,
          'audit_passed' => score >= threshold,
          'failures' => failures,
          'audited_at' => Time.now.utc.iso8601
        }
      end
      log("ListingSeoAuditAgent audited #{listings.size} listings")
    end

    private

    def audit_listing(listing)
      failures = []
      score = 100

      title = listing['title'].to_s
      tags = listing['tags'] || []
      desc = listing['description'].to_s

      unless title.length.between?(120, 140)
        failures << "Title length #{title.length} (target 120-140)"
        score -= 15
      end
      unless tags.size == 13
        failures << "Only #{tags.size}/13 tags used"
        score -= 15
      end
      unless tags.count { |t| t.split.size >= 3 } >= 5
        failures << 'Fewer than 5 long-tail tags'
        score -= 10
      end
      unless title.downcase.match?(/personalise|personaliz|custom/)
        failures << 'No personalisation signal in title'
        score -= 10
      end
      unless listing['images']&.size.to_i >= 7
        failures << "Only #{listing['images']&.size || 0}/7 images"
        score -= 20
      end
      unless desc.split.size >= 100
        failures << 'Description under 100 words'
        score -= 10
      end
      unless desc.downcase.match?(/bulk|wholesale/)
        failures << 'No bulk order mention in description'
        score -= 5
      end

      [[score, 0].max, failures]
    end

    def fetch_listings
      response = faraday.get(
        "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/listings",
        { state: 'active', limit: 100, includes: 'Images' },
        { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}" }
      )
      return [] unless response.success?

      JSON.parse(response.body)['results'] || []
    rescue StandardError => e
      error("ListingSeoAuditAgent: #{e.message}")
      []
    end
  end
end
