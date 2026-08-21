module Agents
  class SeasonalKeywordAgent < Agent
    default_schedule "every_7d"

    description <<~MD
      The **SeasonalKeywordAgent** runs weekly and flags upcoming seasonal opportunities
      8 weeks in advance, generating targeted keyword lists and content suggestions for
      each seasonal event relevant to Lil Rabbit Prints.

      Seasonal events tracked:
      - Valentine's Day (Feb 14) — rabbit couple prints, love gifts
      - Easter (moveable) — easter bunny, spring prints
      - Mother's Day UK (3rd Sunday March) — personalised mum gifts
      - Father's Day UK (3rd Sunday June) — personalised dad gifts
      - Halloween (Oct 31) — spooky bunny art
      - Christmas (Dec 25) — bulk corporate gifts, personalised gifts

      **Options:**
      - `advance_weeks` — how many weeks ahead to flag (default: 8)
      - `expected_update_period_in_days` — for health check
    MD

    event_description <<~MD
      Emits one event per upcoming occasion (if within advance_weeks window).
    MD

    def default_options
      {
        'advance_weeks' => 8,
        'expected_update_period_in_days' => 8
      }
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def check
      today = Date.today
      year = today.year
      advance = interpolated['advance_weeks'].to_i
      occasions = build_occasions(year)
      occasions.each do |occasion|
        days_away = (occasion[:date] - today).to_i
        weeks_away = (days_away / 7.0).ceil
        next unless weeks_away.between?(0, advance)

        create_event payload: {
          'event_type' => 'seasonal_opportunity',
          'occasion' => occasion[:name],
          'date' => occasion[:date].to_s,
          'weeks_away' => weeks_away,
          'keywords' => occasion[:keywords],
          'content_angle' => occasion[:angle],
          'triggered_at' => Time.now.utc.iso8601
        }
      end
    end

    private

    def build_occasions(year)
      [
        { name: "Valentine's Day", date: Date.new(year, 2, 14),
          keywords: ['rabbit valentines gift', 'personalised love print', 'bunny couple print', 'valentines wall art'],
          angle: 'Romantic bunny prints — perfect personalised gift for couples' },
        { name: 'Easter', date: easter_date(year),
          keywords: ['easter bunny gift', 'personalised easter print', 'spring bunny art', 'easter basket gift'],
          angle: 'Easter bunny prints and personalised spring gifts' },
        { name: "Mother's Day UK", date: mothering_sunday(year),
          keywords: ['personalised mum gift', 'rabbit print for mum', 'mother\'s day wall art', 'custom mum print'],
          angle: 'Personalised rabbit prints — a unique gift mum will treasure forever' },
        { name: "Father's Day UK", date: fathers_day_uk(year),
          keywords: ['personalised dad gift', 'rabbit print for dad', 'father\'s day print', 'custom dad art'],
          angle: 'Custom rabbit prints for dad — personalised with his name' },
        { name: 'Halloween', date: Date.new(year, 10, 31),
          keywords: ['halloween bunny print', 'spooky rabbit art', 'halloween wall art', 'cute halloween print'],
          angle: 'Spooky cute rabbit Halloween prints' },
        { name: 'Christmas', date: Date.new(year, 12, 25),
          keywords: ['christmas rabbit gift', 'personalised christmas print', 'bulk corporate christmas gift', 'bunny christmas art'],
          angle: 'Personalised rabbit prints — perfect bulk corporate Christmas gifts' }
      ]
    end

    def easter_date(year)
      a = year % 19; b = year / 100; c = year % 100
      d = b / 4; e = b % 4; f = (b + 8) / 25; g = (b - f + 1) / 3
      h = (19 * a + b - d - g + 15) % 30; i = c / 4; k = c % 4
      l = (32 + 2 * e + 2 * i - h - k) % 7
      m = (a + 11 * h + 22 * l) / 451
      month = (h + l - 7 * m + 114) / 31
      day = (h + l - 7 * m + 114) % 31 + 1
      Date.new(year, month, day)
    end

    def mothering_sunday(year)
      march1 = Date.new(year, 3, 1)
      first_sunday = march1 + ((7 - march1.wday) % 7)
      first_sunday + 14
    end

    def fathers_day_uk(year)
      june1 = Date.new(year, 6, 1)
      first_sunday = june1 + ((7 - june1.wday) % 7)
      first_sunday + 14
    end
  end
end
