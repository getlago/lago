# frozen_string_literal: true

require "rails_helper"

RSpec.describe Clickhouse::ActivityLog, clickhouse: true do
  subject(:activity_log) { create(:clickhouse_activity_log) }

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:resource) }
  it { is_expected.to belong_to(:customer).optional }
  it { is_expected.to belong_to(:subscription).optional }
  it { is_expected.to belong_to(:user).optional }
  it { is_expected.to belong_to(:api_key).optional }

  describe "#ensure_activity_id" do
    it "sets the activity_id if it is not set" do
      expect(activity_log.activity_id).to be_present
    end
  end
end
