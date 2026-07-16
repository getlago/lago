# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::InvoiceSerializer do
  subject(:serializer) { described_class.new(invoice, root_name: "invoice", includes:) }

  let(:includes) { %i[metadata error_details] }

  let(:invoice) { create(:invoice) }

  let(:metadata) { create(:invoice_metadata, invoice:) }
  let(:error_details1) { create(:error_detail, owner: invoice) }
  let(:error_details2) { create(:error_detail, owner: invoice, deleted_at: Time.current) }

  before do
    metadata
    error_details1
    error_details2
  end

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["invoice"]).to include(
      "lago_id" => invoice.id,
      "billing_entity_code" => invoice.billing_entity.code,
      "sequential_id" => invoice.sequential_id,
      "number" => invoice.number,
      "purchase_order_number" => invoice.purchase_order_number,
      "issuing_date" => invoice.issuing_date.iso8601,
      "payment_due_date" => invoice.payment_due_date.iso8601,
      "net_payment_term" => invoice.net_payment_term,
      "invoice_type" => invoice.invoice_type,
      "status" => invoice.status,
      "payment_status" => invoice.payment_status,
      "payment_dispute_lost_at" => invoice.payment_dispute_lost_at,
      "payment_overdue" => invoice.payment_overdue,
      "currency" => invoice.currency,
      "fees_amount_cents" => invoice.fees_amount_cents,
      "progressive_billing_credit_amount_cents" => invoice.progressive_billing_credit_amount_cents,
      "coupons_amount_cents" => invoice.coupons_amount_cents,
      "credit_notes_amount_cents" => invoice.credit_notes_amount_cents,
      "prepaid_credit_amount_cents" => invoice.prepaid_credit_amount_cents,
      "prepaid_granted_credit_amount_cents" => invoice.prepaid_granted_credit_amount_cents,
      "prepaid_purchased_credit_amount_cents" => invoice.prepaid_purchased_credit_amount_cents,
      "taxes_amount_cents" => invoice.taxes_amount_cents,
      "sub_total_excluding_taxes_amount_cents" => invoice.sub_total_excluding_taxes_amount_cents,
      "sub_total_including_taxes_amount_cents" => invoice.sub_total_including_taxes_amount_cents,
      "total_amount_cents" => invoice.total_amount_cents,
      "total_due_amount_cents" => invoice.total_due_amount_cents,
      "file_url" => invoice.file_url,
      "xml_url" => invoice.xml_url,
      "error_details" => [
        {
          "lago_id" => error_details1.id,
          "error_code" => error_details1.error_code,
          "details" => error_details1.details
        }
      ],
      "version_number" => 4,
      "self_billed" => invoice.self_billed,
      "created_at" => invoice.created_at.iso8601,
      "updated_at" => invoice.updated_at.iso8601
    )

    expect(result["invoice"]["metadata"].first).to include(
      "lago_id" => metadata.id,
      "key" => metadata.key,
      "value" => metadata.value
    )
  end

  context "when invoice is a progressive_billing invoice" do
    let(:invoice) { create(:invoice, invoice_type: :progressive_billing) }
    let(:applied_usage_threshold) { create(:applied_usage_threshold, invoice:) }

    before { applied_usage_threshold }

    it "serializes the object" do
      result = JSON.parse(serializer.to_json)

      expect(result["invoice"]["applied_usage_thresholds"].count).to eq(1)
    end
  end

  context "when including billing periods" do
    let(:includes) { %i[billing_periods] }
    let(:invoice_subscription) { create(:invoice_subscription, :boundaries, invoice:) }

    before { invoice_subscription }

    it "serializes the invoice_subscription" do
      result = JSON.parse(serializer.to_json)

      expect(result["invoice"]["billing_periods"]).to be_present
    end
  end

  context "when including subscriptions with multiple subscriptions" do
    let(:includes) { %i[subscriptions billing_periods] }
    let(:organization) { invoice.organization }
    let(:customer) { invoice.customer }

    let(:plan_zebra) { create(:plan, organization:, name: "Zebra Plan", invoice_display_name: nil) }
    let(:plan_alpha) { create(:plan, organization:, name: "Alpha Plan", invoice_display_name: nil) }

    let(:subscription_zebra) { create(:subscription, customer:, plan: plan_zebra, name: nil) }
    let(:subscription_alpha) { create(:subscription, customer:, plan: plan_alpha, name: nil) }
    let(:subscription_custom) { create(:subscription, customer:, plan: plan_zebra, name: "AAA Custom") }

    before do
      create(:invoice_subscription, :boundaries, invoice:, subscription: subscription_zebra)
      create(:invoice_subscription, :boundaries, invoice:, subscription: subscription_alpha)
      create(:invoice_subscription, :boundaries, invoice:, subscription: subscription_custom)
    end

    it "orders subscriptions alphabetically by invoice_name" do
      result = JSON.parse(serializer.to_json)

      expect(result["invoice"]["subscriptions"].map { |s| s["name"] }).to eq([
        "AAA Custom",
        nil,
        nil
      ])
    end

    it "orders billing_periods alphabetically by subscription invoice_name" do
      result = JSON.parse(serializer.to_json)

      billing_period_subscription_ids = result["invoice"]["billing_periods"].pluck("lago_subscription_id")

      expect(billing_period_subscription_ids).to eq([
        subscription_custom.id,
        subscription_alpha.id,
        subscription_zebra.id
      ])
    end
  end

  context "when includes fees" do
    let(:charge) do
      create(:standard_charge, properties: {
        "amount" => "100",
        "presentation_group_keys" => [{"value" => "department", "options" => {"display_in_invoice" => true}}]
      })
    end
    let(:fee1) { create(:charge_fee, charge:, invoice:, presentation_breakdowns: [build(:presentation_breakdown)]) }
    let(:fee2) { create(:fee, invoice:) }

    let(:includes) { %i[fees] }

    before do
      fee1
      fee2
    end

    it "returns fees and presentation breakdowns" do
      result = JSON.parse(serializer.to_json)

      expect(result["invoice"]["fees"].count).to eq(2)
      expect(result["invoice"]["fees"].first["presentation_breakdowns"]).to eq([{"presentation_by" => {"department" => "engineering"}, "units" => "60.0"}])
      expect(result["invoice"]["fees"].second["presentation_breakdowns"]).to eq([])
    end
  end

  context "when the tax was deleted" do
    let(:includes) { %i[applied_taxes] }

    it "still return the tax_id" do
      organization = invoice.organization
      tax = create(:tax, organization:)
      create(:invoice_applied_tax, invoice:, tax:)

      tax.discard!
      invoice.reload
      result = JSON.parse(serializer.to_json)

      expect(result["invoice"]["applied_taxes"].sole["lago_tax_id"]).to be_present
    end
  end
end
