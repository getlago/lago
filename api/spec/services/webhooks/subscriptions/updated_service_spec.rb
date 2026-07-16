# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Subscriptions::UpdatedService do
  subject(:webhook_service) { described_class.new(object: subscription) }

  let(:subscription) { create(:subscription) }
  let(:organization) { subscription.organization }

  describe ".call" do
    it_behaves_like "creates webhook", "subscription.updated", "subscription"
  end
end
