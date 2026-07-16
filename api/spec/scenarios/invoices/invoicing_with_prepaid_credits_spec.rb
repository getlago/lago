# frozen_string_literal: true

require "rails_helper"

describe "Invoicing with prepaid credits", :premium do
  let(:organization) { create(:organization, :with_static_values, webhook_url: nil) }
  let(:customer) { create(:customer, :with_static_values, organization:) }
  let(:billable_metric_1) { create(:billable_metric, organization:, code: "count_1") }
  let(:billable_metric_2) { create(:billable_metric, organization:, code: "count_2") }
  let(:other_billable_metric) { create(:sum_billable_metric, organization:) }
  let(:plan) { create(:plan, organization:, amount_cents: 0) }
  let(:tax) { create(:tax, rate: 24, organization:) }
  let(:external_subscription_id) { SecureRandom.uuid }

  before do
    charge_1 = create(:standard_charge, plan:, billable_metric: billable_metric_1, pay_in_advance: true, properties: {amount: "14.29"})
    create(:charge_applied_tax, charge: charge_1, tax:)

    charge_2 = create(:standard_charge, plan:, billable_metric: billable_metric_2, pay_in_advance: true, properties: {amount: "14.27"})
    create(:charge_applied_tax, charge: charge_2, tax:)

    create(:standard_charge, plan:, billable_metric: other_billable_metric, pay_in_advance: true, properties: {amount: "10"})

    create_subscription({
      external_customer_id: customer.external_id,
      external_id: external_subscription_id,
      plan_code: plan.code
    })
  end

  context "with limitations" do
    it "invoices a customer with prepaid credits" do
      wallet = setup_wallet

      expect(customer.invoices.count).to eq(0)

      test_invoice_with_non_applicable_billable_metric(wallet)
      test_invoice_with_applicable_billable_metric(wallet)
    end

    private

    def setup_wallet
      create_wallet({
        external_customer_id: customer.external_id,
        rate_amount: "1",
        currency: "EUR",
        granted_credits: "39.00",
        invoice_requires_successful_payment: false,
        applies_to: {billable_metric_codes: [billable_metric_1.code, billable_metric_2.code]}
      }, as: :model)
    end

    def test_invoice_with_non_applicable_billable_metric(wallet)
      expect do
        create_event({
          code: other_billable_metric.code,
          external_customer_id: customer.external_id,
          external_subscription_id: external_subscription_id,
          properties: {item_id: "1"}
        })
      end.to change { customer.invoices.count }.by(1)

      invoice = customer.invoices.last
      expect(invoice.prepaid_credit_amount_cents).to eq(0)
    end

    def test_invoice_with_applicable_billable_metric(wallet)
      expect do
        create_event({
          code: billable_metric_1.code,
          external_customer_id: customer.external_id,
          external_subscription_id: external_subscription_id,
          properties: {}
        })
      end.to change { customer.invoices.count }.by(1)

      invoice = customer.invoices.order(:created_at).last

      expect(invoice.total_amount_cents).to eq(0)
      expect(invoice.sub_total_including_taxes_amount.to_d).to eq(17.72)
      expect(invoice.prepaid_credit_amount.to_d).to eq(17.72)

      wallet.reload

      expect(wallet.credits_balance).to eq(21.28)
      expect(wallet.balance.to_d).to eq(21.28)

      expect do
        create_event({
          code: billable_metric_2.code,
          external_customer_id: customer.external_id,
          external_subscription_id: external_subscription_id,
          properties: {}
        })
      end.to change { customer.invoices.count }.by(1)

      invoice = customer.invoices.order(:created_at).last

      expect(invoice.total_amount.to_d).to eq(0)
      expect(invoice.sub_total_including_taxes_amount.to_d).to eq(17.69)
      expect(invoice.prepaid_credit_amount.to_d).to eq(17.69)

      wallet.reload

      expect(wallet.credits_balance).to eq(3.59)
      expect(wallet.balance.to_d).to eq(3.59)
    end
  end
end
