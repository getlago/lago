# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Cashfree::Payments::CreateService do
  subject(:create_service) { described_class.new(payment:) }

  let(:customer) { create(:customer, payment_provider_code: code) }
  let(:organization) { customer.organization }
  let(:chasfree_payment_provider) { create(:cashfree_provider, organization:, code:) }
  let(:cashfree_customer) { create(:cashfree_customer, customer:, payment_provider: chasfree_payment_provider) }
  let(:code) { "stripe_1" }

  let(:invoice) do
    create(
      :invoice,
      organization:,
      customer:,
      total_amount_cents: 200,
      currency: "EUR",
      ready_for_payment_processing: true
    )
  end

  let(:payment) do
    create(
      :payment,
      payable: invoice,
      status: "pending",
      payable_payment_status: "pending",
      payment_provider: chasfree_payment_provider,
      payment_provider_customer: cashfree_customer,
      amount_cents: invoice.total_amount_cents,
      amount_currency: invoice.currency
    )
  end

  describe ".call" do
    before do
      chasfree_payment_provider
      cashfree_customer
    end

    it "returns the payment and keeps it pending" do
      result = create_service.call

      expect(result).to be_success

      expect(result.payment.id).to be_present
      expect(result.payment.payable).to eq(invoice)
      expect(result.payment.payment_provider).to eq(chasfree_payment_provider)
      expect(result.payment.payment_provider_customer).to eq(cashfree_customer)
      expect(result.payment.amount_cents).to eq(invoice.total_amount_cents)
      expect(result.payment.amount_currency).to eq(invoice.currency)
      expect(result.payment.status).to eq("pending")
      expect(result.payment.payable_payment_status).to eq("pending")
    end
  end
end
