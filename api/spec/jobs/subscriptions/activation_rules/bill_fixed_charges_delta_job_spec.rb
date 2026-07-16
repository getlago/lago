# frozen_string_literal: true

require "rails_helper"

describe Subscriptions::ActivationRules::BillFixedChargesDeltaJob do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:, organization:) }

  before do
    allow(Subscriptions::ActivationRules::BillFixedChargesDeltaService).to receive(:call!)
  end

  it "forwards the subscription to the BillFixedChargesDeltaService" do
    described_class.perform_now(subscription)

    expect(Subscriptions::ActivationRules::BillFixedChargesDeltaService).to have_received(:call!).with(subscription:)
  end
end
