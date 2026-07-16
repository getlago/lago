# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::UpdatePaymentReferenceService do
  subject(:service_result) { described_class.call(payment:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:, status: :finalized, number: "INV-2026-001") }
  let(:payment_provider) { create(:stripe_provider, organization:) }
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
      payable_payment_status: :succeeded
    )
  end

  let(:stripe_service_result) do
    PaymentProviders::Stripe::Payments::UpdateReferenceService::Result.new.tap { |r| r.payment = payment }
  end

  before do
    allow(PaymentProviders::Stripe::Payments::UpdateReferenceService).to receive(:call!).and_return(stripe_service_result)
  end

  context "when the payment provider is Stripe" do
    it "delegates to the Stripe update-reference service" do
      service_result

      expect(PaymentProviders::Stripe::Payments::UpdateReferenceService).to have_received(:call!).with(payment:)
    end

    it "returns success with the payment" do
      expect(service_result).to be_success
      expect(service_result.payment).to eq(payment)
    end
  end

  context "when the payment provider is Adyen" do
    let(:payment_provider) { create(:adyen_provider, organization:) }
    let(:adyen_customer) { create(:adyen_customer, customer:, payment_provider:) }
    let(:payment) do
      create(:payment, payable: invoice, payment_provider:, payment_provider_customer: adyen_customer,
        organization:, customer:, provider_payment_id: "psp_ref_123", payable_payment_status: :succeeded)
    end

    it "does not dispatch — Adyen references are immutable post-authorization" do
      expect(service_result).to be_success
      expect(PaymentProviders::Stripe::Payments::UpdateReferenceService).not_to have_received(:call!)
    end
  end

  context "when the payment provider is GoCardless" do
    let(:payment_provider) { create(:gocardless_provider, organization:) }
    let(:gocardless_customer) { create(:gocardless_customer, customer:, payment_provider:) }
    let(:payment) do
      create(:payment, payable: invoice, payment_provider:, payment_provider_customer: gocardless_customer,
        organization:, customer:, provider_payment_id: "PM_abc", payable_payment_status: :succeeded)
    end

    it "does not dispatch — GoCardless never carries the invoice number" do
      expect(service_result).to be_success
      expect(PaymentProviders::Stripe::Payments::UpdateReferenceService).not_to have_received(:call!)
    end
  end

  context "when the payment has no payment_provider" do
    let(:payment) do
      create(:payment, payable: invoice, payment_provider: nil, organization:, customer:,
        provider_payment_id: "pi_test_123", payable_payment_status: :succeeded)
    end

    it "returns a successful result without dispatching" do
      expect(service_result).to be_success
      expect(PaymentProviders::Stripe::Payments::UpdateReferenceService).not_to have_received(:call!)
    end
  end

  context "when the payment has no provider_payment_id" do
    before { payment.update!(provider_payment_id: nil) }

    it "returns a successful result without dispatching" do
      expect(service_result).to be_success
      expect(PaymentProviders::Stripe::Payments::UpdateReferenceService).not_to have_received(:call!)
    end
  end

  context "when the payment provider has no reference update integration" do
    let(:payment_provider) { create(:cashfree_provider, organization:) }
    let(:payment) do
      create(:payment, payable: invoice, payment_provider:, organization:, customer:,
        provider_payment_id: "cf_123", payable_payment_status: :succeeded)
    end

    it "returns a successful result without dispatching" do
      expect(service_result).to be_success
      expect(PaymentProviders::Stripe::Payments::UpdateReferenceService).not_to have_received(:call!)
    end

    it "logs that the provider is skipped" do
      allow(Rails.logger).to receive(:info)

      service_result

      expect(Rails.logger).to have_received(:info)
        .with(a_string_matching(/no PSP reference update for.*CashfreeProvider/))
    end
  end
end
