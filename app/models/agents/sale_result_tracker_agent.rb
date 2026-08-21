module Agents
  class SaleResultTrackerAgent < Agent
    include WebRequestConcern

    default_schedule "every_24h"

    description <<~MD
      The **SaleResultTrackerAgent** checks listing views and favourers 24 hours after a
      promotion was fired and logs the "lift" — the increase attributable to the promotion.

      It maintains a record of all promotions with their pre-promotion baseline and post-24h
      stats, emitting a lift report event for each completed promotion.

      **Options:**
      - `shop_id` — Your Etsy shop ID
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits lift report events:

          {
            "event_type": "promotion_lift_report",
            "listing_id": ...,
            "title": "...",
            "views_before": 340,
            "views_after": 412,
            "views_lift": 72,
            "favorers_lift": 4,
            "promoted_at": "..."
          }
    MD

    def default_options
      {
        'shop_id' => '',
        'api_key' => '',
        'access_token' => '',
        'expected_update_period_in_days' => 2
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
        payload = event.payload
        listing_id = payload['listing_id'].to_s
        next unless listing_id.present?

        stats = fetch_listing_stats(listing_id)
        pending = memory['pending'] ||= {}
        pending[listing_id] = {
          'listing_id' => listing_id,
          'title' => payload['title'],
          'views_before' => stats['views'],
          'favorers_before' => stats['num_favorers'],
          'promoted_at' => Time.now.to_i
        }
        memory['pending'] = pending
        save!
      end
    end

    def check
      pending = memory['pending'] ||= {}
      completed = []
      pending.each do |listing_id, record|
        age_hours = (Time.now.to_i - record['promoted_at'].to_i) / 3600.0
        next unless age_hours >= 24

        stats = fetch_listing_stats(listing_id)
        create_event payload: {
          'event_type' => 'promotion_lift_report',
          'listing_id' => listing_id,
          'title' => record['title'],
          'views_before' => record['views_before'],
          'views_after' => stats['views'],
          'views_lift' => stats['views'].to_i - record['views_before'].to_i,
          'favorers_before' => record['favorers_before'],
          'favorers_after' => stats['num_favorers'],
          'favorers_lift' => stats['num_favorers'].to_i - record['favorers_before'].to_i,
          'promoted_at' => Time.at(record['promoted_at'].to_i).utc.iso8601
        }
        completed << listing_id
      end
      completed.each { |id| pending.delete(id) }
      memory['pending'] = pending
      save!
    end

    private

    def fetch_listing_stats(listing_id)
      response = faraday.get(
        "https://openapi.etsy.com/v3/application/listings/#{listing_id}",
        {},
        { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}" }
      )
      return { 'views' => 0, 'num_favorers' => 0 } unless response.success?

      JSON.parse(response.body)
    rescue StandardError
      { 'views' => 0, 'num_favorers' => 0 }
    end
  end
end
