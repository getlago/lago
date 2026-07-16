# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::CancelPaymentService do
  subject(:result) { described_class.call(payment:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:) }

  before do
    allow(PaymentProviders::Stripe::Payments::CancelService).to receive(:call!)
    allow(PaymentProviders::Adyen::Payments::CancelService).to receive(:call!)
    allow(PaymentProviders::Gocardless::Payments::CancelService).to receive(:call!)
  end

  context "when payment has no payment provider" do
    let(:payment) do
      create(:payment, payable: invoice, payment_provider: nil, organization:, customer:,
        provider_payment_id: "pi_123", payable_payment_status: :pending)
    end

    it "returns a successful result with the payment" do
      expect(result).to be_success
      expect(result.payment).to eq(payment)
    end

    it "does not call any PSP cancel service" do
      result

      expect(PaymentProviders::Stripe::Payments::CancelService).not_to have_received(:call!)
      expect(PaymentProviders::Adyen::Payments::CancelService).not_to have_received(:call!)
      expect(PaymentProviders::Gocardless::Payments::CancelService).not_to have_received(:call!)
    end
  end

  context "when payment has no provider_payment_id" do
    let(:payment_provider) { create(:stripe_provider, organization:) }
    let(:payment) do
      create(:payment, payable: invoice, payment_provider:, organization:, customer:,
        provider_payment_id: nil, payable_payment_status: :pending)
    end

    it "returns a successful result with the payment" do
      expect(result).to be_success
      expect(result.payment).to eq(payment)
    end

    it "does not call any PSP cancel service" do
      result

      expect(PaymentProviders::Stripe::Payments::CancelService).not_to have_received(:call!)
    end
  end

  context "when payment is already succeeded" do
    let(:payment_provider) { create(:stripe_provider, organization:) }
    let(:payment) do
      create(:payment, payable: invoice, payment_provider:, organization:, customer:,
        provider_payment_id: "pi_123", payable_payment_status: :succeeded)
    end

    it "returns a successful result with the payment" do
      expect(result).to be_success
      expect(result.payment).to eq(payment)
    end

    it "does not call the PSP cancel service (canceling a succeeded payment would be destructive)" do
      result

      expect(PaymentProviders::Stripe::Payments::CancelService).not_to have_received(:call!)
    end
  end

  context "when the provider is Stripe" do
    let(:payment_provider) { create(:stripe_provider, organization:) }
    let(:payment) do
      create(:payment, payable: invoice, payment_provider:, organization:, customer:,
        provider_payment_id: "pi_123", payable_payment_status: :pending)
    end

    it "routes to the Stripe cancel service with the payment" do
      result

      expect(PaymentProviders::Stripe::Payments::CancelService).to have_received(:call!).with(payment:)
    end

    it "does not call the other PSP cancel services" do
      result

      expect(PaymentProviders::Adyen::Payments::CancelService).not_to have_received(:call!)
      expect(PaymentProviders::Gocardless::Payments::CancelService).not_to have_received(:call!)
    end
  end

  context "when the provider is Adyen" do
    let(:payment_provider) { create(:adyen_provider, organization:) }
    let(:provider_customer) { create(:adyen_customer, customer:, payment_provider:) }
    let(:payment) do
      create(:payment, payable: invoice, payment_provider:, payment_provider_customer: provider_customer,
        organization:, customer:, provider_payment_id: "PSPREF123", payable_payment_status: :pending)
    end

    it "routes to the Adyen cancel service with the payment" do
      result

      expect(PaymentProviders::Adyen::Payments::CancelService).to have_received(:call!).with(payment:)
    end

    it "does not call the other PSP cancel services" do
      result

      expect(PaymentProviders::Stripe::Payments::CancelService).not_to have_received(:call!)
      expect(PaymentProviders::Gocardless::Payments::CancelService).not_to have_received(:call!)
    end
  end

  context "when the provider is GoCardless" do
    let(:payment_provider) { create(:gocardless_provider, organization:) }
    let(:provider_customer) { create(:gocardless_customer, customer:, payment_provider:) }
    let(:payment) do
      create(:payment, payable: invoice, payment_provider:, payment_provider_customer: provider_customer,
        organization:, customer:, provider_payment_id: "PM123", payable_payment_status: :pending)
    end

    it "routes to the GoCardless cancel service with the payment" do
      result

      expect(PaymentProviders::Gocardless::Payments::CancelService).to have_received(:call!).with(payment:)
    end

    it "does not call the other PSP cancel services" do
      result

      expect(PaymentProviders::Stripe::Payments::CancelService).not_to have_received(:call!)
      expect(PaymentProviders::Adyen::Payments::CancelService).not_to have_received(:call!)
    end
  end

  context "when the provider has no dedicated cancel service (Cashfree, Flutterwave, MoneyHash)" do
    let(:payment_provider) { create(:cashfree_provider, organization:) }
    let(:payment) do
      create(:payment, payable: invoice, payment_provider:, organization:, customer:,
        provider_payment_id: "cf_123", payable_payment_status: :pending)
    end

    it "returns a successful result without calling any PSP cancel service" do
      result

      expect(result).to be_success
      expect(PaymentProviders::Stripe::Payments::CancelService).not_to have_received(:call!)
      expect(PaymentProviders::Adyen::Payments::CancelService).not_to have_received(:call!)
      expect(PaymentProviders::Gocardless::Payments::CancelService).not_to have_received(:call!)
    end

    it "logs that the provider is unsupported" do
      allow(Rails.logger).to receive(:info)

      result

      expect(Rails.logger).to have_received(:info)
        .with(a_string_matching(/PSP cancel not supported.*CashfreeProvider/))
    end
  end
end
