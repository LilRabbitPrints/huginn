module Agents
  class TwitterTrendAgent < Agent
    cannot_be_scheduled!

    description <<~MD
      The **TwitterTrendAgent** monitors Twitter/X for trending hashtags and buyer language
      relevant to your product niche. It receives trigger events and searches for recent tweets
      containing monitored hashtags, extracting high-frequency terms buyers are using.

      **Options:**
      - `bearer_token` — Twitter API v2 ******
      - `hashtags_to_monitor` — array of hashtags to search (without #)
      - `max_results` — tweets per hashtag search (default: 100)
      - `extract_top_n_terms` — top N terms to emit per hashtag (default: 5)
      - `expected_receive_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits trending term events:

          {
            "keyword": "cottagecore nursery",
            "source": "twitter_trend",
            "hashtag": "EtsySeller",
            "frequency": 12,
            "collected_at": "..."
          }
    MD

    def default_options
      {
        'bearer_token' => '',
        'hashtags_to_monitor' => %w[EtsySeller NurseryDecor CottageCore BunnyArt RabbitLover PersonalisedGifts EtsyUK WallArtDecor],
        'max_results' => 100,
        'extract_top_n_terms' => 5,
        'expected_receive_period_in_days' => 2
      }
    end

    def validate_options
      errors.add(:base, 'bearer_token is required') if options['bearer_token'].blank?
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do
        hashtags = interpolated['hashtags_to_monitor'] || []
        hashtags.each do |hashtag|
          terms = search_hashtag(hashtag)
          terms.first(interpolated['extract_top_n_terms'].to_i).each do |term, freq|
            create_event payload: {
              'keyword' => term,
              'source' => 'twitter_trend',
              'hashtag' => hashtag,
              'frequency' => freq,
              'collected_at' => Time.now.utc.iso8601
            }
          end
        end
      end
    end

    private

    def search_hashtag(hashtag)
      response = faraday.get(
        'https://api.twitter.com/2/tweets/search/recent',
        { query: "##{hashtag} -is:retweet lang:en", max_results: [interpolated['max_results'].to_i, 100].min },
        { 'Authorization' => "******'bearer_token']}" }
      )
      return [] unless response.success?

      tweets = JSON.parse(response.body)['data'] || []
      word_freq = Hash.new(0)
      stopwords = %w[the a an and or but in on at to for of with is are was were]
      tweets.each do |tweet|
        tweet['text'].to_s.downcase.scan(/\b[a-z]{4,}\b/).each do |word|
          word_freq[word] += 1 unless stopwords.include?(word)
        end
      end
      word_freq.sort_by { |_, v| -v }.first(20)
    rescue StandardError => e
      error("TwitterTrendAgent error for ##{hashtag}: #{e.message}")
      []
    end
  end
end
