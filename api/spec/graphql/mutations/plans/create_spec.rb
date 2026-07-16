# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Plans::Create, :premium do
  let(:required_permission) { "plans:create" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:plan_tax) { create(:tax, organization:) }
  let(:charge_tax) { create(:tax, organization:) }
  let(:commitment_tax) { create(:tax, organization:) }
  let(:minimum_commitment_invoice_display_name) { "Minimum spending" }
  let(:minimum_commitment_amount_cents) { 100 }

  let(:feature) { create(:feature, code: :seats, organization:) }
  let(:privilege) { create(:privilege, feature:, code: "max", value_type: "integer") }
  let(:entitlement) { create(:entitlement, feature:, plan:) }
  let(:entitlement_value) { create(:entitlement_value, privilege:, entitlement:, value: "99") }

  let(:feature2) { create(:feature, code: "sso", organization:) }

  let(:mutation) do
    <<~GQL
      mutation($input: CreatePlanInput!) {
        createPlan(input: $input) {
          id,
          name,
          invoiceDisplayName,
          code,
          interval,
          payInAdvance,
          amountCents,
          amountCurrency,
          billChargesMonthly,
          billFixedChargesMonthly,
          taxes { id code rate }
          minimumCommitment {
            id,
            amountCents,
            invoiceDisplayName,
            taxes { id code rate }
          }
          charges {
            id,
            chargeModel,
            billableMetric { id name code }
            taxes { id code rate }
            appliedPricingUnit {
              id
              conversionRate
              pricingUnit { id code name }
            }
            properties {
              amount,
              presentationGroupKeys { value options { displayInInvoice } }
              freeUnits,
              packageSize,
              rate,
              fixedAmount,
              freeUnitsPerEvents,
              freeUnitsPerTotalAggregation,
              graduatedRanges { fromValue, toValue }
              volumeRanges { fromValue, toValue }
              graduatedPercentageRanges { fromValue toValue }
              perTransactionMaxAmount
              perTransactionMinAmount
            }
            filters {
              invoiceDisplayName
              values
              properties {
                amount
              }
            }
          }
          fixedCharges {
            id,
            chargeModel,
            addOn { id name code }
            taxes { id code rate }
            properties {
              amount,
              graduatedRanges { fromValue, toValue }
              volumeRanges { fromValue, toValue }
            }
          }
          usageThresholds {
            amountCents,
            thresholdDisplayName,
            recurring
          }
          entitlements {
            code
            privileges { code value }
          }
        }
      }
    GQL
  end

  let(:billable_metrics) do
    create_list(:billable_metric, 6, organization:)
  end

  let(:add_ons) do
    create_list(:add_on, 3, organization:)
  end

  let(:billable_metric_filter) do
    create(
      :billable_metric_filter,
      billable_metric: billable_metrics[0],
      key: "payment_method",
      values: %w[card sepa]
    )
  end

  let(:tax) { create(:tax, organization:) }
  let(:pricing_unit) { create(:pricing_unit, organization:) }

  before { organization.update!(premium_integrations: ["progressive_billing"]) }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "plans:create"

  it "creates a plan" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          name: "New Plan",
          invoiceDisplayName: "New Plan Invoice Name",
          code: "new_plan",
          interval: "monthly",
          payInAdvance: false,
          amountCents: 200,
          amountCurrency: "EUR",
          taxCodes: [plan_tax.code],
          minimumCommitment: {
            amountCents: minimum_commitment_amount_cents,
            invoiceDisplayName: minimum_commitment_invoice_display_name,
            taxCodes: [commitment_tax.code]
          },
          charges: [
            {
              billableMetricId: billable_metrics[0].id,
              chargeModel: "standard",
              properties: {
                amount: "100.00",
                presentationGroupKeys: [
                  {
                    value: "region",
                    options: {
                      displayInInvoice: true
                    }
                  }
                ]
              },
              taxCodes: [charge_tax.code],
              appliedPricingUnit: {
                code: pricing_unit.code,
                conversionRate: 2.5
              },
              filters: [
                {
                  invoiceDisplayName: "Payment Method",
                  properties: {
                    amount: "100.00"
                  },
                  values: {billable_metric_filter.key => %w[card sepa]}
                }
              ]
            },
            {
              billableMetricId: billable_metrics[1].id,
              chargeModel: "package",
              properties: {
                amount: "300.00",
                freeUnits: 10,
                packageSize: 10
              }
            },
            {
              billableMetricId: billable_metrics[2].id,
              chargeModel: "percentage",
              properties: {
                rate: "0.25",
                fixedAmount: "2",
                freeUnitsPerEvents: 5,
                freeUnitsPerTotalAggregation: "50",
                perTransactionMaxAmount: "20",
                perTransactionMinAmount: "10"
              }
            },
            {
              billableMetricId: billable_metrics[3].id,
              chargeModel: "graduated",
              properties: {
                graduatedRanges: [
                  {
                    fromValue: 0,
                    toValue: 10,
                    perUnitAmount: "2.00",
                    flatAmount: "0"
                  },
                  {
                    fromValue: 11,
                    toValue: nil,
                    perUnitAmount: "3.00",
                    flatAmount: "3.00"
                  }
                ]
              }
            },
            {
              billableMetricId: billable_metrics[4].id,
              chargeModel: "volume",
              properties: {
                volumeRanges: [
                  {
                    fromValue: 0,
                    toValue: 10,
                    perUnitAmount: "2.00",
                    flatAmount: "0"
                  },
                  {
                    fromValue: 11,
                    toValue: nil,
                    perUnitAmount: "3.00",
                    flatAmount: "3.00"
                  }
                ]
              }
            },
            {
              billableMetricId: billable_metrics[5].id,
              chargeModel: "graduated_percentage",
              properties: {
                graduatedPercentageRanges: [
                  {
                    fromValue: 0,
                    toValue: 10,
                    flatAmount: "0",
                    rate: "2"
                  },
                  {
                    fromValue: 11,
                    toValue: nil,
                    flatAmount: "3.00",
                    rate: "3"
                  }
                ]
              }
            }
          ],
          fixedCharges: [
            {
              addOnId: add_ons[0].id,
              chargeModel: "standard",
              properties: {amount: "100.00"},
              taxCodes: [charge_tax.code]
            },
            {
              addOnId: add_ons[1].id,
              chargeModel: "graduated",
              properties: {
                graduatedRanges: [
                  {
                    fromValue: 0,
                    toValue: 10,
                    perUnitAmount: "2.00",
                    flatAmount: "0"
                  },
                  {
                    fromValue: 11,
                    toValue: nil,
                    perUnitAmount: "3.00",
                    flatAmount: "3.00"
                  }
                ]
              }
            },
            {
              addOnId: add_ons[2].id,
              chargeModel: "volume",
              properties: {
                volumeRanges: [
                  {
                    fromValue: 0,
                    toValue: 10,
                    perUnitAmount: "5.00",
                    flatAmount: "0"
                  },
                  {
                    fromValue: 11,
                    toValue: nil,
                    perUnitAmount: "1.00",
                    flatAmount: "2.00"
                  }
                ]
              }
            }
          ],
          usageThresholds: [
            {
              amountCents: 100,
              thresholdDisplayName: "Threshold 1"
            },
            {
              amountCents: 200,
              thresholdDisplayName: "Threshold 2"
            },
            {
              amountCents: 1,
              thresholdDisplayName: "Threshold 3 Recurring",
              recurring: true
            }
          ],
          entitlements: [
            {featureCode: feature.code, privileges: [{privilegeCode: privilege.code, value: "22"}]},
            {featureCode: feature2.code, privileges: []}
          ]
        }
      }
    )

    result_data = result["data"]["createPlan"]

    expect(result_data["id"]).to be_present
    expect(result_data["name"]).to eq("New Plan")
    expect(result_data["invoiceDisplayName"]).to eq("New Plan Invoice Name")
    expect(result_data["code"]).to eq("new_plan")
    expect(result_data["interval"]).to eq("monthly")
    expect(result_data["payInAdvance"]).to eq(false)
    expect(result_data["amountCents"]).to eq("200")
    expect(result_data["billChargesMonthly"]).to be_nil
    expect(result_data["billFixedChargesMonthly"]).to be_nil
    expect(result_data["taxes"][0]["code"]).to eq(plan_tax.code)
    expect(result_data["charges"].count).to eq(6)
    expect(result_data["fixedCharges"].count).to eq(3)
    expect(result_data["usageThresholds"].count).to eq(3)

    standard_charge = result_data["charges"][0]
    expect(standard_charge["properties"]["amount"]).to eq("100.00")
    expect(standard_charge.dig("properties", "presentationGroupKeys")).to eq([
      {"value" => "region", "options" => {"displayInInvoice" => true}}
    ])
    expect(standard_charge["chargeModel"]).to eq("standard")
    expect(standard_charge["taxes"].count).to eq(1)
    expect(standard_charge["taxes"].first["code"]).to eq(charge_tax.code)

    applied_pricing_unit = standard_charge["appliedPricingUnit"]
    expect(applied_pricing_unit).to be_present
    expect(applied_pricing_unit["conversionRate"]).to eq(2.5)
    expect(applied_pricing_unit["pricingUnit"]["code"]).to eq(pricing_unit.code)
    expect(applied_pricing_unit["pricingUnit"]["name"]).to eq(pricing_unit.name)

    filter = standard_charge["filters"].first
    expect(filter["invoiceDisplayName"]).to eq("Payment Method")
    expect(filter["properties"]["amount"]).to eq("100.00")
    expect(filter["values"]).to eq("payment_method" => %w[card sepa])

    package_charge = result_data["charges"][1]
    expect(package_charge["chargeModel"]).to eq("package")
    package_properties = package_charge["properties"]
    expect(package_properties["amount"]).to eq("300.00")
    expect(package_properties["freeUnits"]).to eq("10")
    expect(package_properties["packageSize"]).to eq("10")

    percentage_charge = result_data["charges"][2]
    expect(percentage_charge["chargeModel"]).to eq("percentage")
    percentage_properties = percentage_charge["properties"]
    expect(percentage_properties["rate"]).to eq("0.25")
    expect(percentage_properties["fixedAmount"]).to eq("2")
    expect(percentage_properties["freeUnitsPerEvents"]).to eq("5")
    expect(percentage_properties["freeUnitsPerTotalAggregation"]).to eq("50")

    graduated_charge = result_data["charges"][3]
    expect(graduated_charge["chargeModel"]).to eq("graduated")
    expect(graduated_charge["properties"]["graduatedRanges"].count).to eq(2)

    volume_charge = result_data["charges"][4]
    expect(volume_charge["chargeModel"]).to eq("volume")
    expect(volume_charge["properties"]["volumeRanges"].count).to eq(2)

    graduated_percentage_charge = result_data["charges"][5]
    expect(graduated_percentage_charge["chargeModel"]).to eq("graduated_percentage")
    expect(graduated_percentage_charge["properties"]["graduatedPercentageRanges"].count).to eq(2)

    expect(result_data["minimumCommitment"]).to include(
      "invoiceDisplayName" => minimum_commitment_invoice_display_name,
      "amountCents" => minimum_commitment_amount_cents.to_s
    )
    expect(result_data["minimumCommitment"]["taxes"].count).to eq(1)

    thresholds = result_data["usageThresholds"].sort_by { |threshold| threshold["thresholdDisplayName"] }
    expect(thresholds).to include hash_including(
      "thresholdDisplayName" => "Threshold 1",
      "amountCents" => "100",
      "recurring" => false
    )
    expect(thresholds).to include hash_including(
      "thresholdDisplayName" => "Threshold 2",
      "amountCents" => "200",
      "recurring" => false
    )
    expect(thresholds).to include hash_including(
      "thresholdDisplayName" => "Threshold 3 Recurring",
      "amountCents" => "1",
      "recurring" => true
    )

    expect(result_data["entitlements"]).to contain_exactly(
      {
        "code" => "seats",
        "privileges" => [{"code" => "max", "value" => "22"}]
      }, {
        "code" => "sso",
        "privileges" => []
      }
    )
    standard_fixed_charge = result_data["fixedCharges"][0]
    expect(standard_fixed_charge["properties"]["amount"]).to eq("100.00")
    expect(standard_fixed_charge["chargeModel"]).to eq("standard")
    expect(standard_fixed_charge["taxes"].count).to eq(1)
    expect(standard_fixed_charge["taxes"].first["code"]).to eq(charge_tax.code)

    graduated_fixed_charge = result_data["fixedCharges"][1]
    expect(graduated_fixed_charge["chargeModel"]).to eq("graduated")
    expect(graduated_fixed_charge["properties"]["graduatedRanges"].count).to eq(2)

    volume_fixed_charge = result_data["fixedCharges"][2]
    expect(volume_fixed_charge["chargeModel"]).to eq("volume")
    expect(volume_fixed_charge["properties"]["volumeRanges"].count).to eq(2)
  end

  context "when fixed charges are not provided" do
    it "creates a plan without fixed charges" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            name: "Plan Without Fixed Charges",
            invoiceDisplayName: "No Fixed Charges Plan",
            code: "no_fixed_charges_plan",
            interval: "monthly",
            payInAdvance: false,
            amountCents: 100,
            amountCurrency: "USD",
            charges: []
          }
        }
      )

      result_data = result["data"]["createPlan"]

      expect(result_data["id"]).to be_present
      expect(result_data["fixedCharges"]).to be_empty
    end
  end

  context "when interval is yearly" do
    it "creates a plan with monthly billing for charges and fixed charges" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            name: "New Plan",
            invoiceDisplayName: "New Plan Invoice Name",
            code: "new_plan",
            interval: "yearly",
            payInAdvance: true,
            amountCents: 200,
            amountCurrency: "EUR",
            billChargesMonthly: true,
            billFixedChargesMonthly: true,
            charges: [],
            fixedCharges: []
          }
        }
      )

      result_data = result["data"]["createPlan"]

      expect(result_data["billChargesMonthly"]).to be true
      expect(result_data["billFixedChargesMonthly"]).to be true
    end
  end

  context "when entitlements is nil" do
    it "does not call PlanEntitlementsUpdateService" do
      allow(::Entitlement::PlanEntitlementsUpdateService).to receive(:call)

      execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            name: "Plan without entitlements",
            code: "plan_no_entitlements",
            interval: "monthly",
            payInAdvance: false,
            amountCents: 100,
            amountCurrency: "USD",
            charges: []
          }
        }
      )

      expect(::Entitlement::PlanEntitlementsUpdateService).not_to have_received(:call)
    end
  end

  context "when entitlements is an empty array" do
    it "calls PlanEntitlementsUpdateService to remove all entitlements" do
      allow(::Entitlement::PlanEntitlementsUpdateService).to receive(:call)
        .and_return(BaseService::Result.new)

      execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            name: "Plan empty entitlements",
            code: "plan_empty_entitlements",
            interval: "monthly",
            payInAdvance: false,
            amountCents: 100,
            amountCurrency: "USD",
            charges: [],
            entitlements: []
          }
        }
      )

      expect(::Entitlement::PlanEntitlementsUpdateService).to have_received(:call).with(
        organization: organization,
        plan: Plan.last,
        entitlements_params: {},
        partial: false,
        send_webhook: false
      )
    end
  end

  context "with the plan webhooks" do
    let(:input_with_entitlements) do
      {
        name: "Plan with entitlements",
        code: "plan_with_entitlements",
        interval: "monthly",
        payInAdvance: false,
        amountCents: 100,
        amountCurrency: "USD",
        charges: [],
        entitlements: [
          {featureCode: feature.code, privileges: [{privilegeCode: privilege.code, value: "22"}]}
        ]
      }
    end

    it "emits plan.created but not plan.updated" do
      execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {input: input_with_entitlements}
      )

      expect(SendWebhookJob).to have_been_enqueued.with("plan.created", Plan.last).once
      expect(SendWebhookJob).not_to have_been_enqueued.with("plan.updated", anything)
    end

    it "does not emit the webhook from Plans::CreateService so entitlements are persisted first" do
      allow(::Plans::CreateService).to receive(:call).and_call_original

      execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {input: input_with_entitlements}
      )

      expect(::Plans::CreateService).to have_received(:call).with(anything, send_webhook: false)
    end
  end

  context "with metadata" do
    let(:mutation) do
      <<~GQL
        mutation($input: CreatePlanInput!) {
          createPlan(input: $input) {
            id
            code
            metadata { key value }
          }
        }
      GQL
    end

    it "creates plan with metadata" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            name: "Plan with metadata",
            code: "plan_with_metadata",
            interval: "monthly",
            payInAdvance: false,
            amountCents: 100,
            amountCurrency: "USD",
            charges: [],
            metadata: [{key: "foo", value: "bar"}, {key: "baz", value: "qux"}]
          }
        }
      )

      result_data = result["data"]["createPlan"]
      expect(result_data["id"]).to be_present
      expect(result_data["code"]).to eq("plan_with_metadata")
      expect(result_data["metadata"]).to match_array([
        {"key" => "foo", "value" => "bar"},
        {"key" => "baz", "value" => "qux"}
      ])
    end
  end
end
