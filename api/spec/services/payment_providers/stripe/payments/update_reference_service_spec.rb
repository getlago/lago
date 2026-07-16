# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Stripe::Payments::UpdateReferenceService do
  subject(:service_result) { described_class.call(payment:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:, status: :finalized, number: "INV-2026-001") }
  let(:payment_provider) { create(:stripe_provider, organization:, secret_key: "sk_test_123") }
  let(:stripe_customer) { create(:stripe_customer, customer:, payment_provider:) }
  let(:payment) do
    create(
      :payment,
      payable: invoice,
      payment_provider:,
      payment_provider_customer: stripe_customer,
      organization:,
      customer:,
      provider_payment_id: "pi_test_123",
      payable_payment_status: :succeeded,
      amount_cents: 25_00,
      amount_currency: "EUR"
    )
  end

  before do
    allow(::Stripe::PaymentIntent).to receive(:update)
  end

  it "calls Stripe with the finalized invoice number in description and metadata" do
    service_result

    expect(::Stripe::PaymentIntent).to have_received(:update).with(
      "pi_test_123",
      {
        description: "INV-2026-001",
        metadata: {lago_invoice_number: "INV-2026-001"}
      },
      {api_key: "sk_test_123"}
    )
  end

  it "returns success with the payment" do
    expect(service_result).to be_success
    expect(service_result.payment).to eq(payment)
  end

  context "when the payment has no provider_payment_id" do
    before { payment.update!(provider_payment_id: nil) }

    it "skips the Stripe call" do
      service_result

      expect(::Stripe::PaymentIntent).not_to have_received(:update)
    end

    it "returns success" do
      expect(service_result).to be_success
    end
  end

  context "when the payable is not an Invoice" do
    let(:payment_request) { create(:payment_request, customer:, organization:) }
    let(:payment) do
      create(:payment, payable: payment_request, payment_provider:, payment_provider_customer: stripe_customer,
        organization:, customer:, provider_payment_id: "pi_test_123", payable_payment_status: :succeeded)
    end

    it "skips the Stripe call" do
      service_result

      expect(::Stripe::PaymentIntent).not_to have_received(:update)
    end

    it "returns success" do
      expect(service_result).to be_success
    end
  end

  context "when the invoice has no number yet" do
    before do
      invoice.update_column(:number, "") # rubocop:disable Rails/SkipsModelValidations
    end

    it "skips the Stripe call" do
      service_result

      expect(::Stripe::PaymentIntent).not_to have_received(:update)
    end
  end

  context "when Stripe returns an error" do
    before do
      allow(::Stripe::PaymentIntent).to receive(:update)
        .and_raise(::Stripe::InvalidRequestError.new("No such payment_intent", "id"))
    end

    it "logs a warning and returns success" do
      allow(Rails.logger).to receive(:warn)

      expect(service_result).to be_success
      expect(Rails.logger).to have_received(:warn)
        .with(a_string_matching(/failed to update Stripe PaymentIntent pi_test_123/))
    end

    it "does not raise" do
      expect { service_result }.not_to raise_error
    end
  end
end
