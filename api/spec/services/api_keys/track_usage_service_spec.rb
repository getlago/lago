# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiKeys::TrackUsageService, cache: :memory do
  describe "#call" do
    subject { described_class.call }

    let(:used_api_key) { create(:api_key) }
    let(:unused_api_key) { create(:api_key) }
    let(:last_used_at) { 1.hour.ago.iso8601 }
    let(:cache_key) { "api_key_last_used_#{used_api_key.id}" }

    before { Rails.cache.write(cache_key, last_used_at) }

    it "updates when API key was last used" do
      expect { subject }.to change { used_api_key.reload.last_used_at&.iso8601 }.to last_used_at
    end

    it "clears cache after processing" do
      expect { subject }.to change { Rails.cache.exist?(cache_key) }.to(false)
    end

    it "does not update unused key" do
      expect { subject }.not_to change { unused_api_key.reload.last_used_at }
    end
  end
end
