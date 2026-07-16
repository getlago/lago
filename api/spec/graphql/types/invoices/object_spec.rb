# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Invoices::Object do
  subject { described_class }

  it "has the expected fields with correct types" do
    expect(subject).to have_field(:customer).of_type("Customer!")
    expect(subject).to have_field(:billing_entity).of_type("BillingEntity!")

    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:number).of_type("String!")
    expect(subject).to have_field(:sequential_id).of_type("ID!")

    expect(subject).to have_field(:self_billed).of_type("Boolean!")
    expect(subject).to have_field(:version_number).of_type("Int!")

    expect(subject).to have_field(:invoice_type).of_type("InvoiceTypeEnum!")
    expect(subject).to have_field(:payment_dispute_losable).of_type("Boolean!")
    expect(subject).to have_field(:payment_dispute_lost_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:payment_status).of_type("InvoicePaymentStatusTypeEnum!")
    expect(subject).to have_field(:status).of_type("InvoiceStatusTypeEnum!")
    expect(subject).to have_field(:voidable).of_type("Boolean!")

    expect(subject).to have_field(:currency).of_type("CurrencyEnum")
    expect(subject).to have_field(:taxes_rate).of_type("Float!")

    expect(subject).to have_field(:charge_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:coupons_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:credit_notes_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:fees_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:prepaid_credit_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:prepaid_granted_credit_amount_cents).of_type("BigInt")
    expect(subject).to have_field(:prepaid_purchased_credit_amount_cents).of_type("BigInt")
    expect(subject).to have_field(:progressive_billing_credit_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:sub_total_excluding_taxes_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:sub_total_including_taxes_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:taxes_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:total_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:total_due_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:total_paid_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:total_settled_amount_cents).of_type("BigInt!")

    expect(subject).to have_field(:issuing_date).of_type("ISO8601Date!")
    expect(subject).to have_field(:expected_finalization_date).of_type("ISO8601Date!")
    expect(subject).to have_field(:payment_due_date).of_type("ISO8601Date!")
    expect(subject).to have_field(:payment_overdue).of_type("Boolean!")
    expect(subject).to have_field(:ready_for_payment_processing).of_type("Boolean!")
    expect(subject).to have_field(:all_charges_have_fees).of_type("Boolean!")
    expect(subject).to have_field(:all_fixed_charges_have_fees).of_type("Boolean!")

    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")

    expect(subject).to have_field(:creditable_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:offsettable_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:refundable_amount_cents).of_type("BigInt!")

    expect(subject).to have_field(:file_url).of_type("String")
    expect(subject).to have_field(:xml_url).of_type("String")
    expect(subject).to have_field(:metadata).of_type("[InvoiceMetadata!]")

    expect(subject).to have_field(:activity_logs).of_type("[ActivityLog!]")
    expect(subject).to have_field(:applied_taxes).of_type("[InvoiceAppliedTax!]")
    expect(subject).to have_field(:credit_notes).of_type("[CreditNote!]")
    expect(subject).to have_field(:fees).of_type("[Fee!]")
    expect(subject).to have_field(:invoice_subscriptions).of_type("[InvoiceSubscription!]")
    expect(subject).to have_field(:subscriptions).of_type("[Subscription!]")

    expect(subject).to have_field(:external_hubspot_integration_id).of_type("String")
    expect(subject).to have_field(:external_salesforce_integration_id).of_type("String")
    expect(subject).to have_field(:external_integration_id).of_type("String")
    expect(subject).to have_field(:integration_hubspot_syncable).of_type("Boolean!")
    expect(subject).to have_field(:integration_salesforce_syncable).of_type("Boolean!")
    expect(subject).to have_field(:integration_syncable).of_type("Boolean!")
    expect(subject).to have_field(:payments).of_type("[Payment!]")

    expect(subject).to have_field(:tax_provider_id).of_type("String")

    expect(subject).to have_field(:regenerated_invoice_id).of_type("String")
    expect(subject).to have_field(:voided_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:voided_invoice_id).of_type("String")
  end

  describe "#subscriptions" do
    subject(:subscriptions) { run_graphql_field("Invoice.subscriptions", invoice) }

    let(:invoice) { create(:invoice) }
    let(:organization) { invoice.organization }
    let(:customer) { invoice.customer }

    let(:plan_zebra) { create(:plan, organization:, name: "Zebra Plan", invoice_display_name: nil) }
    let(:plan_alpha) { create(:plan, organization:, name: "Alpha Plan", invoice_display_name: nil) }

    let(:subscription_zebra) { create(:subscription, customer:, plan: plan_zebra, name: nil) }
    let(:subscription_alpha) { create(:subscription, customer:, plan: plan_alpha, name: nil) }
    let(:subscription_custom) { create(:subscription, customer:, plan: plan_zebra, name: "AAA Custom") }

    before do
      create(:invoice_subscription, invoice:, subscription: subscription_zebra)
      create(:invoice_subscription, invoice:, subscription: subscription_alpha)
      create(:invoice_subscription, invoice:, subscription: subscription_custom)
    end

    it "returns subscriptions ordered alphabetically by invoice_name" do
      expect(subscriptions.map(&:invoice_name)).to eq([
        "AAA Custom",
        "Alpha Plan",
        "Zebra Plan"
      ])
    end
  end

  describe "#invoice_subscriptions" do
    subject(:invoice_subscriptions) { run_graphql_field("Invoice.invoiceSubscriptions", invoice) }

    let(:invoice) { create(:invoice) }
    let(:organization) { invoice.organization }
    let(:customer) { invoice.customer }

    let(:plan_zebra) { create(:plan, organization:, name: "Zebra Plan", invoice_display_name: nil) }
    let(:plan_alpha) { create(:plan, organization:, name: "Alpha Plan", invoice_display_name: nil) }

    let(:subscription_zebra) { create(:subscription, customer:, plan: plan_zebra, name: nil) }
    let(:subscription_alpha) { create(:subscription, customer:, plan: plan_alpha, name: nil) }
    let(:subscription_custom) { create(:subscription, customer:, plan: plan_zebra, name: "AAA Custom") }

    before do
      create(:invoice_subscription, invoice:, subscription: subscription_zebra)
      create(:invoice_subscription, invoice:, subscription: subscription_alpha)
      create(:invoice_subscription, invoice:, subscription: subscription_custom)
    end

    it "returns invoice_subscriptions ordered alphabetically by subscription invoice_name" do
      expect(invoice_subscriptions.map { |is| is.subscription.invoice_name }).to eq([
        "AAA Custom",
        "Alpha Plan",
        "Zebra Plan"
      ])
    end
  end

  describe "#payments" do
    subject(:payments) { run_graphql_field("Invoice.payments", invoice) }

    let(:invoice) { create(:invoice) }

    before do
      create(:payment, payable: invoice, payable_payment_status: :succeeded, amount_cents: 100, updated_at: 1.hour.ago)
      create(:payment, payable: invoice, payable_payment_status: :succeeded, amount_cents: 200, updated_at: 2.hours.ago)
    end

    it "returns payments ordered by updated_at" do
      expect(payments.map(&:amount_cents)).to eq([100, 200])
    end
  end
end
