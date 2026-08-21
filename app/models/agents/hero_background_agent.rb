module Agents
  class HeroBackgroundAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **HeroBackgroundAgent** selects the most appropriate lifestyle background scene
      for the hero image based on product type, season, and target audience signals.

      Background scenes available:
      - `nursery_shelf` — for prints/posters targeting new parents
      - `kitchen_counter` — for mugs/kitchen items
      - `garden_path` — for outdoor/tote products
      - `wooden_desk` — for cards/stationery
      - `sofa_throw` — for cushions/home decor
      - `gift_wrap_table` — for gift-focused campaigns
      - `woodland_flat_lay` — for cottagecore/nature aesthetic

      **Options:**
      - `background_overrides` — JSON map of `listing_id` to forced background scene
      - `seasonal_backgrounds` — JSON map of season to preferred background
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `selected_background` and `background_rationale` fields.
    MD

    PRODUCT_BACKGROUNDS = {
      'print' => 'nursery_shelf',
      'mug' => 'kitchen_counter',
      'tote' => 'garden_path',
      'card' => 'wooden_desk',
      'cushion' => 'sofa_throw'
    }.freeze

    SEASONAL_BACKGROUNDS = {
      'spring' => 'garden_path',
      'summer' => 'garden_path',
      'autumn' => 'woodland_flat_lay',
      'winter' => 'gift_wrap_table'
    }.freeze

    def default_options
      {
        'background_overrides' => {},
        'seasonal_backgrounds' => SEASONAL_BACKGROUNDS,
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        listing_id = payload['listing_id'].to_s
        overrides = interpolated['background_overrides'] || {}

        background = if overrides[listing_id]
                       overrides[listing_id]
                     elsif payload['bulk_focus']
                       'gift_wrap_table'
                     else
                       product_background(payload)
                     end

        rationale = "product=#{payload['product_type']}, season=#{current_season}, bulk=#{payload['bulk_focus']}"
        create_event payload: payload.merge(
          'selected_background' => background,
          'background_rationale' => rationale
        )
      end
    end

    private

    def product_background(payload)
      product_type = payload['product_type'] || 'print'
      seasonal = (interpolated['seasonal_backgrounds'] || {})[current_season]
      PRODUCT_BACKGROUNDS[product_type] || seasonal || 'nursery_shelf'
    end

    def current_season
      month = Date.today.month
      case month
      when 3..5 then 'spring'
      when 6..8 then 'summer'
      when 9..11 then 'autumn'
      else 'winter'
      end
    end
  end
end
