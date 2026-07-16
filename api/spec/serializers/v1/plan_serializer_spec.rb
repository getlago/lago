# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::PlanSerializer do
  subject(:serializer) do
    described_class.new(
      plan,
      root_name: "plan",
      includes: %i[charges fixed_charges entitlements taxes minimum_commitment usage_thresholds]
    )
  end

  let(:plan) { create(:plan) }
  let(:customer) { create(:customer, organization: plan.organization) }
  let(:subscription) { create(:subscription, customer:, plan:) }
  let(:charge) { create(:standard_charge, plan:) }
  let(:usage_threshold) { create(:usage_threshold, plan:) }

  before do
    subscription
    charge
    usage_threshold
  end

  context "when plan has one minimium commitment" do
    let(:commitment) { create(:commitment, plan:) }

    before { commitment }

    it "serializes the object" do
      overridden_plan = create(:plan, parent_id: plan.id)
      customer2 = create(:customer, organization: plan.organization)
      create(:subscription, customer: customer2, plan: overridden_plan)

      result = JSON.parse(serializer.to_json)

      expect(result["plan"]).to include(
        "lago_id" => plan.id,
        "name" => plan.name,
        "invoice_display_name" => plan.invoice_display_name,
        "created_at" => plan.created_at.iso8601,
        "code" => plan.code,
        "interval" => plan.interval,
        "description" => plan.description,
        "amount_cents" => plan.amount_cents,
        "amount_currency" => plan.amount_currency,
        "trial_period" => plan.trial_period,
        "pay_in_advance" => plan.pay_in_advance,
        "bill_charges_monthly" => plan.bill_charges_monthly,
        "bill_fixed_charges_monthly" => plan.bill_fixed_charges_monthly,
        "customers_count" => 0,
        "active_subscriptions_count" => 0,
        "draft_invoices_count" => 0,
        "parent_id" => nil,
        "pending_deletion" => false,
        "taxes" => []
      )

      expect(result["plan"]["charges"].first).to include(
        "lago_id" => charge.id
      )

      expect(result["plan"]["entitlements"]).to be_empty

      expect(result["plan"]["usage_thresholds"].first).to include(
        "lago_id" => usage_threshold.id,
        "threshold_display_name" => usage_threshold.threshold_display_name,
        "amount_cents" => usage_threshold.amount_cents,
        "recurring" => usage_threshold.recurring?,
        "created_at" => usage_threshold.created_at.iso8601,
        "updated_at" => usage_threshold.updated_at.iso8601
      )

      expect(result["plan"]["minimum_commitment"]).to include(
        "lago_id" => commitment.id,
        "plan_code" => commitment.plan.code,
        "invoice_display_name" => commitment.invoice_display_name,
        "amount_cents" => commitment.amount_cents,
        "interval" => commitment.plan.interval,
        "created_at" => commitment.created_at.iso8601,
        "updated_at" => commitment.updated_at.iso8601,
        "taxes" => []
      )
      expect(result["plan"]["minimum_commitment"]).not_to include(
        "commitment_type" => "minimum_commitment"
      )
    end
  end

  context "when plan has no minimium commitment" do
    it "serializes the object" do
      overridden_plan = create(:plan, parent_id: plan.id)
      customer2 = create(:customer, organization: plan.organization)
      create(:subscription, customer: customer2, plan: overridden_plan)

      result = JSON.parse(serializer.to_json)

      expect(result["plan"]).to include(
        "lago_id" => plan.id,
        "name" => plan.name,
        "invoice_display_name" => plan.invoice_display_name,
        "created_at" => plan.created_at.iso8601,
        "code" => plan.code,
        "interval" => plan.interval,
        "description" => plan.description,
        "amount_cents" => plan.amount_cents,
        "amount_currency" => plan.amount_currency,
        "trial_period" => plan.trial_period,
        "pay_in_advance" => plan.pay_in_advance,
        "bill_charges_monthly" => plan.bill_charges_monthly,
        "customers_count" => 0,
        "active_subscriptions_count" => 0,
        "draft_invoices_count" => 0,
        "parent_id" => nil,
        "taxes" => []
      )

      expect(result["plan"]["charges"].first).to include(
        "lago_id" => charge.id
      )

      expect(result["plan"]["usage_thresholds"].first).to include(
        "lago_id" => usage_threshold.id,
        "threshold_display_name" => usage_threshold.threshold_display_name,
        "amount_cents" => usage_threshold.amount_cents,
        "recurring" => usage_threshold.recurring?,
        "created_at" => usage_threshold.created_at.iso8601,
        "updated_at" => usage_threshold.updated_at.iso8601
      )

      expect(result["plan"]["minimum_commitment"]).to be_nil
    end
  end

  context "when plan has entitlements" do
    let(:feature) { create(:feature, organization: plan.organization, code: "seats", name: "Seats", description: "Nb users") }
    let(:privilege) { create(:privilege, feature:, code: "max", value_type: "integer") }
    let(:entitlement) { create(:entitlement, feature:, plan:) }
    let(:entitlement_value) { create(:entitlement_value, entitlement:, privilege:, value: 100) }

    before { entitlement_value }

    it "serializes the entitlements" do
      result = JSON.parse(serializer.to_json)
      expect(result["plan"]["entitlements"].count).to eq 1
      expect(result["plan"]["entitlements"].first).to eq({
        "code" => "seats",
        "name" => "Seats",
        "description" => "Nb users",
        "privileges" => [
          {
            "code" => "max",
            "name" => nil,
            "value" => 100,
            "config" => {},
            "value_type" => "integer"
          }
        ]
      })
    end
  end

  context "when plan has fixed charges" do
    let(:fixed_charge) { create(:fixed_charge, plan:) }
    let(:tax) { create(:tax, organization: plan.organization) }
    let(:fixed_charge_tax) { create(:fixed_charge_applied_tax, fixed_charge:, tax:) }

    before do
      fixed_charge
      fixed_charge_tax
    end

    it "serializes the fixed charges" do
      result = JSON.parse(serializer.to_json)
      expect(result["plan"]["fixed_charges"].count).to eq(1)
      expect(result["plan"]["fixed_charges"].first).to include({
        "lago_id" => fixed_charge.id,
        "lago_add_on_id" => fixed_charge.add_on_id,
        "invoice_display_name" => fixed_charge.invoice_display_name,
        "add_on_code" => fixed_charge.add_on.code
      })
      expect(result["plan"]["fixed_charges"].first["taxes"].count).to eq(1)
      expect(result["plan"]["fixed_charges"].first["taxes"].first).to include({
        "lago_id" => tax.id,
        "name" => tax.name,
        "code" => tax.code,
        "rate" => tax.rate
      })
    end
  end

  context "when applicable_usage_thresholds is included" do
    subject(:serializer) do
      described_class.new(
        plan,
        root_name: "plan",
        includes: %i[applicable_usage_thresholds]
      )
    end

    it "serializes applicable_usage_thresholds without lago_id, created_at, and updated_at" do
      result = JSON.parse(serializer.to_json)

      expect(result["plan"]["applicable_usage_thresholds"].count).to eq(1)
      expect(result["plan"]["applicable_usage_thresholds"].first).to eq(
        "threshold_display_name" => usage_threshold.threshold_display_name,
        "amount_cents" => usage_threshold.amount_cents,
        "recurring" => usage_threshold.recurring?
      )
    end
  end
end
