module Agents
  class TagReplacementSuggesterAgent < Agent
    include WebRequestConcern

    cannot_be_scheduled!

    description <<~MD
      The **TagReplacementSuggesterAgent** takes the gap analysis and your current tag inventory
      and produces specific per-listing tag swap recommendations: "replace [weak tag] with
      [trending gap keyword] on listing [ID]".

      It identifies the weakest-performing tags on each listing (least distinctive, most generic)
      and suggests replacements from the gap keyword list.

      **Options:**
      - `api_key` — Etsy v3 API key
      - `access_token` — Etsy OAuth2 access token
      - `shop_id` — Your Etsy shop ID
      - `max_swaps_per_listing` — max tag swap suggestions per listing (default: 3)
      - `weak_tag_patterns` — regex patterns for tags to prioritise replacing (e.g. very generic tags)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits one event per listing with suggested tag swaps:

          {
            "event_type": "tag_swap_suggestions",
            "listing_id": 1234567890,
            "listing_title": "...",
            "swaps": [
              {"remove": "art", "add": "personalised rabbit nursery art"},
              ...
            ]
          }
    MD

    def default_options
      {
        'api_key' => '',
        'access_token' => '',
        'shop_id' => '',
        'max_swaps_per_listing' => 3,
        'weak_tag_patterns' => ['^\w{1,4}$', '^(art|print|gift|home|decor)$'],
        'expected_receive_period_in_days' => 4
      }
    end

    def validate_options
      errors.add(:base, 'api_key is required') if options['api_key'].blank?
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        next unless event.payload['event_type'] == 'gap_analysis'

        gap_keywords = (event.payload['top_gaps'] || []).map { |g| g['keyword'] }
        listings = fetch_listings
        listings.each do |listing|
          swaps = suggest_swaps(listing, gap_keywords)
          next if swaps.empty?

          create_event payload: {
            'event_type' => 'tag_swap_suggestions',
            'listing_id' => listing['listing_id'],
            'listing_title' => listing['title'],
            'swaps' => swaps,
            'generated_at' => Time.now.utc.iso8601
          }
        end
      end
    end

    private

    def suggest_swaps(listing, gap_keywords)
      tags = listing['tags'] || []
      weak_patterns = (interpolated['weak_tag_patterns'] || []).map { |p| Regexp.new(p) }
      weak_tags = tags.select { |t| weak_patterns.any? { |p| t.match?(p) } }
      max = interpolated['max_swaps_per_listing'].to_i
      used_gaps = []
      weak_tags.first(max).filter_map do |weak|
        replacement = gap_keywords.find { |g| !tags.include?(g) && !used_gaps.include?(g) }
        next unless replacement

        used_gaps << replacement
        { 'remove' => weak, 'add' => replacement }
      end
    end

    def fetch_listings
      response = faraday.get(
        "https://openapi.etsy.com/v3/application/shops/#{interpolated['shop_id']}/listings",
        { state: 'active', limit: 100 },
        { 'x-api-key' => interpolated['api_key'], 'Authorization' => "******'access_token']}" }
      )
      return [] unless response.success?

      JSON.parse(response.body)['results'] || []
    rescue StandardError => e
      error("TagReplacementSuggesterAgent: #{e.message}")
      []
    end
  end
end
