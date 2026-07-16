# frozen_string_literal: true

require "rails_helper"

RSpec.describe Clock::ApiKeys::TrackUsageJob, job: true do
  describe ".perform" do
    subject { described_class.perform_now }

    before { allow(ApiKeys::TrackUsageService).to receive(:call) }

    it "tracks API keys last usage" do
      subject
      expect(ApiKeys::TrackUsageService).to have_received(:call)
    end
  end
end
