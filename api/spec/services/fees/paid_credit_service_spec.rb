# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fees::PaidCreditService do
  subject(:paid_credit_service) do
    described_class.new(invoice:, customer:, wallet_transaction:)
  end

  let(:customer) { create(:customer) }
  let(:organization) { customer.organization }
  let(:billing_entity) { customer.billing_entity }
  let(:invoice) { create(:invoice, organization:) }
  let(:subscription) { create(:subscription, customer:) }
  let(:wallet) { create(:wallet, customer:, rate_amount: "1.00") }
  let(:wallet_transaction) do
    create(:wallet_transaction, wallet:, amount: "15.00", credit_amount: "15.00")
  end

  before { subscription }

  describe ".create" do
    it "creates a fee" do
      result = paid_credit_service.create

      expect(result).to be_success
      expect(result.fee).to have_attributes(
        id: String,
        fee_type: "credit",
        organization_id: organization.id,
        billing_entity_id: billing_entity.id,
        invoice_id: invoice.id,
        invoiceable_type: "WalletTransaction",
        invoiceable_id: wallet_transaction.id,
        amount_cents: 1500,
        precise_amount_cents: 1500.0,
        amount_currency: "EUR",
        taxes_amount_cents: 0,
        taxes_precise_amount_cents: 0.0,
        taxes_rate: 0,
        unit_amount_cents: 100,
        units: 15,
        payment_status: "pending",
        precise_unit_amount: 1
      )
    end

    context "when fee already exists on the period" do
      before do
        create(
          :fee,
          invoiceable_type: "WalletTransaction",
          invoiceable_id: wallet_transaction.id,
          invoice:
        )
      end

      it "does not create a new fee" do
        expect { paid_credit_service.create }.not_to change(Fee, :count)
      end
    end
  end
end
