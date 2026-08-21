require 'net/smtp'

module Agents
  class ListingConfirmationAgent < Agent
    include EmailConcern

    cannot_be_scheduled!

    description <<~MD
      The **ListingConfirmationAgent** sends you a confirmation email when a listing has been
      activated (or is ready to review as a draft). The email contains:

      - Direct link to the live/draft listing on Etsy
      - Listing title and SEO score
      - A checklist confirming which pipeline steps completed successfully
      - One-click approve link (if the listing is still in draft state)

      **Options:**
      - `recipients` — email address(es) to notify
      - `etsy_shop_url` — your Etsy shop URL (used to build the listing link)
      - `approve_webhook_url` — URL buyers hit to trigger ListingActivatorAgent (for draft approvals)
      - `expected_receive_period_in_days` — for health check
    MD

    def default_options
      {
        'recipients' => [],
        'etsy_shop_url' => 'https://www.etsy.com/shop/LilRabbitPrints',
        'approve_webhook_url' => '',
        'expected_receive_period_in_days' => 2
      }
    end

    def validate_options
      errors.add(:base, 'recipients must be provided') if options['recipients'].blank?
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload
        listing_id = payload['new_listing_id'] || payload['listing_id']
        next unless listing_id

        send_confirmation(listing_id, payload)
      end
    end

    private

    def send_confirmation(listing_id, payload)
      title = payload['title'] || payload['optimized_title'] || 'Unknown'
      listing_url = payload['listing_url'] || payload['draft_url'] ||
                    "https://www.etsy.com/listing/#{listing_id}"
      state = payload['state'] || (payload['event_type'] == 'listing_activated' ? 'active' : 'draft')
      seo_score = payload['seo_score']
      uploaded_count = payload['uploaded_count']

      checklist = build_checklist(payload)
      approve_link = approve_url(listing_id, payload)

      body = <<~HTML
        <h2>🐇 Listing #{state == 'active' ? 'Live!' : 'Draft Ready for Review'}</h2>
        <p><strong>Title:</strong> #{title}</p>
        <p><strong>Listing:</strong> <a href="#{listing_url}">#{listing_url}</a></p>
        #{seo_score ? "<p><strong>SEO Score:</strong> #{seo_score}/100</p>" : ''}
        #{uploaded_count ? "<p><strong>Images Uploaded:</strong> #{uploaded_count}/7</p>" : ''}
        <h3>Pipeline Checklist</h3>
        #{checklist}
        #{approve_link}
      HTML

      recipients.each do |recipient|
        SystemMailer.send_message(
          to: recipient,
          from: ENV['EMAIL_FROM_ADDRESS'],
          subject: "🐇 #{state == 'active' ? 'New Listing Live' : 'Draft Ready'}: #{title.truncate(60)}",
          headline: nil,
          body: body,
          content_type: 'text/html',
          groups: []
        ).deliver_now
        log("Sent confirmation to #{recipient} for listing #{listing_id}")
      rescue StandardError => e
        error("ListingConfirmationAgent email error: #{e.message}")
      end
    end

    def build_checklist(payload)
      items = [
        ['Brief generated', payload['optimized_title'].present?],
        ['Tags generated (13)', payload['tags']&.size == 13],
        ['Description written', payload['long_description'].present?],
        ['SEO score ≥ 80', payload['seo_score'].to_i >= 80],
        ['Mockup images ready', payload['mockup_images'].present?],
        ['All 7 images uploaded', payload['uploaded_count'].to_i == 7]
      ]
      rows = items.map { |label, done| "<li>#{done ? '✅' : '❌'} #{label}</li>" }.join
      "<ul>#{rows}</ul>"
    end

    def approve_url(listing_id, payload)
      return '' if interpolated['approve_webhook_url'].blank? || payload['state'] == 'active'

      url = "#{interpolated['approve_webhook_url']}?listing_id=#{listing_id}&approved=true"
      "<p><a href='#{url}' style='background:#e75b2e;color:white;padding:10px 20px;text-decoration:none;border-radius:4px;'>✅ Approve &amp; Activate Listing</a></p>"
    end
  end
end
