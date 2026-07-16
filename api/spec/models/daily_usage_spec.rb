# frozen_string_literal: true

require "rails_helper"

RSpec.describe DailyUsage do
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:customer) }
  it { is_expected.to belong_to(:subscription) }
end
