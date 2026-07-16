# frozen_string_literal: true

require "rails_helper"

describe Subscriptions::ActivationRules::BillMissedPeriodsJob do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:, organization:) }

  before do
    allow(Subscriptions::ActivationRules::BillMissedPeriodsService).to receive(:call!)
  end

  it "forwards the subscription to the BillMissedPeriodsService" do
    described_class.perform_now(subscription)

    expect(Subscriptions::ActivationRules::BillMissedPeriodsService).to have_received(:call!).with(subscription:)
  end
end
