# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::ActivationRules::ExpireIncompleteJob do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, :incomplete, customer:, organization:) }

  before do
    allow(Subscriptions::ActivationRules::ExpireService).to receive(:call!)
  end

  it "forwards the subscription to the ExpireService" do
    described_class.perform_now(subscription)

    expect(Subscriptions::ActivationRules::ExpireService).to have_received(:call!).with(subscription:)
  end
end
