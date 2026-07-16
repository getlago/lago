# frozen_string_literal: true

require "rails_helper"

RSpec.describe Clickhouse::ApiLog, clickhouse: true do
  subject(:api_log) { create(:clickhouse_api_log) }

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:api_key) }

  describe "#ensure_request_id" do
    it "sets the request_id if it is not set" do
      expect(api_log.request_id).to be_present
    end
  end
end
