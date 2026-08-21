module Agents
  class DetailZoomAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **DetailZoomAgent** determines the optimal crop region for the product detail image,
      identifying the most visually rich area (print zone, embroidery, handle, etc.) based on
      product type and design metadata.

      It enriches the detail spec with `crop_region` (a named region or pixel coordinates) and
      `zoom_factor` for the mockup generator.

      **Options:**
      - `crop_regions` — JSON map of product type to crop region name
      - `zoom_factor` — magnification level for the crop (default: 1.8)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits payload with `crop_region` and `zoom_factor` merged into `detail_spec`.
    MD

    def default_options
      {
        'crop_regions' => {
          'print' => 'center_print_area',
          'mug' => 'front_wrap_zone',
          'tote' => 'front_panel',
          'card' => 'front_center',
          'cushion' => 'front_panel'
        },
        'zoom_factor' => 1.8,
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
        regions = interpolated['crop_regions'] || {}
        crop = regions[product_type] || 'center'
        detail_spec = (payload['detail_spec'] || {}).merge(
          'crop_region' => crop,
          'zoom_factor' => interpolated['zoom_factor'].to_f
        )
        create_event payload: payload.merge('detail_spec' => detail_spec)
      end
    end
  end
end
