# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Plans::UpdatedService do
  subject(:webhook_service) { described_class.new(object: plan) }

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }

  describe ".call" do
    it_behaves_like "creates webhook", "plan.updated", "plan", {
      "code" => String,
      "charges" => Array,
      "usage_thresholds" => Array,
      "taxes" => Array,
      "entitlements" => Array
    }
  end
end
