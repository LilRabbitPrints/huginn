module Agents
  class DesignFileResolverAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **DesignFileResolverAgent** maps each listing's product type (or shop section ID) to
      the correct design file reference in your mockup generator app. It supports nested lookups:
      product type → variant → season → design file.

      **Options:**
      - `design_library` — JSON map of `product_type:variant:season` to design file path/reference
      - `default_design` — fallback design file path
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `design_file_ref` and `design_resolution_path` fields added.
    MD

    def default_options
      {
        'design_library' => {
          'print:standard:any' => 'designs/rabbit_print_standard_v2.png',
          'print:personalised:any' => 'designs/rabbit_print_personalised_v3.png',
          'mug:standard:any' => 'designs/rabbit_mug_wrap_v1.png',
          'tote:standard:any' => 'designs/rabbit_tote_front_v1.png',
          'card:standard:any' => 'designs/rabbit_card_v2.png'
        },
        'default_design' => 'designs/rabbit_default.png',
        'expected_receive_period_in_days' => 2
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        product_type = payload['product_type'] || 'print'
        variant = payload['is_customizable'] ? 'personalised' : 'standard'
        season = current_season
        lib = interpolated['design_library'] || {}

        design_file = lib["#{product_type}:#{variant}:#{season}"] ||
                      lib["#{product_type}:#{variant}:any"] ||
                      lib["#{product_type}:standard:any"] ||
                      interpolated['default_design']

        resolution_path = "#{product_type}:#{variant}:#{season}"
        create_event payload: payload.merge(
          'design_file_ref' => design_file,
          'design_resolution_path' => resolution_path
        )
      end
    end

    private

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
