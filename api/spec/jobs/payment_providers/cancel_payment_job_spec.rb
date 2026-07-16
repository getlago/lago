# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::CancelPaymentJob do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:payment_provider) { create(:stripe_provider, organization:) }
  let(:payment) do
    create(:payment, payable: invoice, payment_provider:, organization:, customer:,
      provider_payment_id: "pi_123", payable_payment_status: :pending)
  end

  before do
    allow(PaymentProviders::CancelPaymentService).to receive(:call!)
  end

  it "forwards the payment to the dispatcher service" do
    described_class.perform_now(payment)

    expect(PaymentProviders::CancelPaymentService).to have_received(:call!).with(payment:)
  end
end
