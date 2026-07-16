# frozen_string_literal: true

require "rails_helper"

RSpec.describe Clickhouse::EventsDeadLetter, clickhouse: true do
  subject(:event_dead_letter) { create(:clickhouse_events_dead_letter) }

  it { is_expected.to belong_to(:organization) }
end
