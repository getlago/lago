# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Plans::Update do
  let(:required_permission) { "plans:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:plan) { create(:plan, organization:) }
  let(:minimum_commitment_invoice_display_name) { "Minimum spending" }
  let(:minimum_commitment_amount_cents) { 100 }
  let(:commitment_tax) { create(:tax, organization:) }

  let(:feature) { create(:feature, code: :seats, organization:) }
  let(:privilege) { create(:privilege, feature:, code: "max", value_type: "integer") }
  let(:entitlement) { create(:entitlement, feature:, plan:) }
  let(:entitlement_value) { create(:entitlement_value, privilege:, entitlement:, value: "99") }

  let(:feature2) { create(:feature, code: "sso", organization:) }

  let(:mutation) do
    <<~GQL
      mutation($input: UpdatePlanInput!) {
        updatePlan(input: $input) {
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
          minimumCommitment {
            id,
            amountCents,
            invoiceDisplayName,
            taxes { id code rate }
          },
          charges {
            id,
            chargeModel,
            billableMetric { id name code },
            appliedPricingUnit {
              id
              conversionRate
              pricingUnit { id code name }
            },
            properties {
              amount,
              presentationGroupKeys { value options { displayInInvoice } }
              freeUnits,
              packageSize,
              rate,
              fixedAmount,
              freeUnitsPerEvents,
              freeUnitsPerTotalAggregation,
              graduatedRanges { fromValue, toValue },
              volumeRanges { fromValue, toValue }
            }
            filters {
              invoiceDisplayName
              values
              properties {
                amount
              }
            }
          },
          fixedCharges {
            id,
            units,
            addOn { id name code },
            chargeModel,
            properties {
             amount
             graduatedRanges { fromValue, toValue },
             volumeRanges { fromValue, toValue }
            }
          },
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
    create_list(:billable_metric, 5, organization:)
  end

  let(:billable_metric_filter) do
    create(
      :billable_metric_filter,
      billable_metric: billable_metrics[0],
      key: "payment_method",
      values: %w[card sepa]
    )
  end

  let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:) }
  let(:pricing_unit) { create(:pricing_unit, organization:) }

  let(:graphql) do
    {
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          id: plan.id,
          name: "Updated plan",
          invoiceDisplayName: "Updated plan invoice name",
          code: "new_plan",
          interval: "monthly",
          payInAdvance: false,
          amountCents: "200",
          amountCurrency: "EUR",
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
              appliedPricingUnit: {
                code: pricing_unit.code,
                conversionRate: 0.1
              },
              filters: [
                {
                  invoiceDisplayName: "Payment method",
                  properties: {
                    amount: "10.00"
                  },
                  values: {billable_metric_filter.key => %w[card]}
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
                freeUnitsPerTotalAggregation: "50"
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
    }
  end

  before do
    minimum_commitment
    entitlement_value
    feature2
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "plans:update"

  context "with premium license", :premium do
    before { organization.update!(premium_integrations: ["progressive_billing"]) }

    it "updates a plan" do
      result = execute_graphql(**graphql)
      result_data = result["data"]["updatePlan"]

      expect(result_data["id"]).to be_present
      expect(result_data["name"]).to eq("Updated plan")
      expect(result_data["invoiceDisplayName"]).to eq("Updated plan invoice name")
      expect(result_data["code"]).to eq("new_plan")
      expect(result_data["interval"]).to eq("monthly")
      expect(result_data["payInAdvance"]).to eq(false)
      expect(result_data["amountCents"]).to eq("200")
      expect(result_data["amountCurrency"]).to eq("EUR")
      expect(result_data["charges"].count).to eq(5)
      expect(result_data["usageThresholds"].count).to eq(3)

      standard_charge = result_data["charges"][0]
      expect(standard_charge["properties"]["amount"]).to eq("100.00")
      expect(standard_charge.dig("properties", "presentationGroupKeys")).to eq([
        {"value" => "region", "options" => {"displayInInvoice" => true}}
      ])
      expect(standard_charge["chargeModel"]).to eq("standard")

      applied_pricing_unit = standard_charge["appliedPricingUnit"]
      expect(applied_pricing_unit).to be_present
      expect(applied_pricing_unit["conversionRate"]).to eq(0.1)
      expect(applied_pricing_unit["pricingUnit"]["code"]).to eq(pricing_unit.code)
      expect(applied_pricing_unit["pricingUnit"]["name"]).to eq(pricing_unit.name)

      filter = standard_charge["filters"].first
      expect(filter["invoiceDisplayName"]).to eq("Payment method")
      expect(filter["properties"]["amount"]).to eq("10.00")
      expect(filter["values"]).to eq("payment_method" => %w[card])

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
    end

    it "updates minimum commitment" do
      result = execute_graphql(**graphql)
      result_data = result["data"]["updatePlan"]

      expect(result_data["minimumCommitment"]).to include(
        "invoiceDisplayName" => minimum_commitment_invoice_display_name,
        "amountCents" => minimum_commitment_amount_cents.to_s
      )
      expect(result_data["minimumCommitment"]["taxes"].count).to eq(1)
    end
  end

  context "without premium license" do
    it "updates a plan" do
      result = execute_graphql(**graphql)
      result_data = result["data"]["updatePlan"]

      expect(result_data["id"]).to be_present
      expect(result_data["name"]).to eq("Updated plan")
      expect(result_data["invoiceDisplayName"]).to eq("Updated plan invoice name")
      expect(result_data["code"]).to eq("new_plan")
      expect(result_data["interval"]).to eq("monthly")
      expect(result_data["payInAdvance"]).to eq(false)
      expect(result_data["amountCents"]).to eq("200")
      expect(result_data["amountCurrency"]).to eq("EUR")
      expect(result_data["charges"].count).to eq(5)

      standard_charge = result_data["charges"][0]
      expect(standard_charge["properties"]["amount"]).to eq("100.00")
      expect(standard_charge.dig("properties", "presentationGroupKeys")).to eq([
        {"value" => "region", "options" => {"displayInInvoice" => true}}
      ])
      expect(standard_charge["chargeModel"]).to eq("standard")

      expect(standard_charge["appliedPricingUnit"]).to be_nil

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

      expect(result_data["entitlements"]).to contain_exactly(
        {
          "code" => "seats",
          "privileges" => [{"code" => "max", "value" => "22"}]
        }, {
          "code" => "sso",
          "privileges" => []
        }
      )
    end

    it "does not update minimum commitment" do
      result = execute_graphql(**graphql)
      result_data = result["data"]["updatePlan"]

      expect(result_data["minimumCommitment"]).to include(
        "invoiceDisplayName" => minimum_commitment.invoice_display_name,
        "amountCents" => minimum_commitment.amount_cents.to_s
      )
    end
  end

  context "when entitlements is nil" do
    it "does not call PlanEntitlementsUpdateService" do
      allow(::Entitlement::PlanEntitlementsUpdateService).to receive(:call)

      execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: plan.id,
            name: "Updated plan",
            code: "updated_plan",
            interval: "monthly",
            payInAdvance: false,
            amountCents: 200,
            amountCurrency: "EUR",
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
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: plan.id,
            name: "Updated plan",
            code: "updated_plan",
            interval: "monthly",
            payInAdvance: false,
            amountCents: 200,
            amountCurrency: "EUR",
            charges: [],
            entitlements: []
          }
        }
      )

      expect(::Entitlement::PlanEntitlementsUpdateService).to have_received(:call).with(
        organization: organization,
        plan:,
        entitlements_params: {},
        partial: false,
        send_webhook: false
      )
    end
  end

  context "with the plan.updated webhook" do
    let(:base_input) do
      {
        id: plan.id,
        name: "Updated plan",
        code: "updated_plan",
        interval: "monthly",
        payInAdvance: false,
        amountCents: 200,
        amountCurrency: "EUR",
        charges: []
      }
    end

    context "when entitlements are not provided" do
      it "enqueues a single plan.updated webhook" do
        execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query: mutation,
          variables: {input: base_input}
        )

        expect(SendWebhookJob).to have_been_enqueued.with("plan.updated", plan).once
      end
    end

    context "when entitlements are provided", :premium do
      let(:input_with_entitlements) do
        base_input.merge(
          entitlements: [
            {featureCode: feature.code, privileges: [{privilegeCode: privilege.code, value: "22"}]}
          ]
        )
      end

      it "enqueues a single plan.updated webhook" do
        execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query: mutation,
          variables: {input: input_with_entitlements}
        )

        expect(SendWebhookJob).to have_been_enqueued.with("plan.updated", plan).once
      end

      it "does not emit the webhook from Plans::UpdateService so entitlements are persisted first" do
        allow(::Plans::UpdateService).to receive(:call).and_call_original

        execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query: mutation,
          variables: {input: input_with_entitlements}
        )

        expect(::Plans::UpdateService).to have_received(:call).with(plan:, params: anything, send_webhook: false)
      end
    end
  end

  context "when charges are not provided" do
    let(:existing_charge) do
      create(:standard_charge, plan:, billable_metric: billable_metrics[0], properties: {amount: "42.00"})
    end

    before do
      existing_charge
    end

    it "updates the plan without changing charges" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: plan.id,
            name: "Updated plan",
            code: "updated_plan",
            interval: "monthly",
            payInAdvance: true,
            amountCents: 200,
            amountCurrency: "EUR"
          }
        }
      )

      result_data = result["data"]["updatePlan"]

      expect(result_data["name"]).to eq("Updated plan")
      expect(result_data["charges"].count).to eq(1)
      expect(result_data["charges"].first["id"]).to eq(existing_charge.id)
      expect(result_data["charges"].first["properties"]["amount"]).to eq("42.00")
    end
  end

  context "when fixed charges are not provided" do
    let(:fixed_charge) { create(:fixed_charge, plan:, charge_model: "standard", properties: {amount: "100.00"}) }

    before do
      fixed_charge
    end

    it "updates the plan without changing fixed charges" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: plan.id,
            name: "Updated plan",
            code: "updated_plan",
            interval: "monthly",
            payInAdvance: true,
            amountCents: 200,
            amountCurrency: "EUR",
            charges: []
          }
        }
      )

      result_data = result["data"]["updatePlan"]

      expect(result_data["fixedCharges"].count).to eq(1)
      expect(result_data["fixedCharges"].first["id"]).to eq(fixed_charge.id)
    end
  end

  context "when fixed charges are provided" do
    let(:add_ons) { create_list(:add_on, 5, organization:) }
    let(:add_on_1) { add_ons[0] }
    let(:add_on_2) { add_ons[1] }
    let(:add_on_3) { add_ons[2] }
    let(:add_on_4) { add_ons[3] }
    let(:add_on_5) { add_ons[4] }

    let(:fixed_charge_1) { create(:fixed_charge, plan:, add_on: add_on_1, units: 10) }
    let(:fixed_charge_2) { create(:fixed_charge, plan:, add_on: add_on_2, units: 5) }

    let(:active_subscription) { create(:subscription, plan:) }

    before do
      fixed_charge_1
      fixed_charge_2
      active_subscription
    end

    it "updates the plan with the provided fixed charges" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: plan.id,
            name: "Updated plan",
            code: "updated_plan",
            interval: "monthly",
            payInAdvance: true,
            amountCents: 200,
            amountCurrency: "EUR",
            charges: [],
            fixedCharges: [
              {
                id: fixed_charge_1.id,
                addOnId: add_on_1.id,
                # does not change units
                units: "10",
                chargeModel: "standard",
                properties: {amount: "10.00"},
                applyUnitsImmediately: true
              },
              {
                id: fixed_charge_2.id,
                addOnId: add_on_2.id,
                # changes units
                units: "20.55",
                chargeModel: "standard",
                properties: {amount: "100.00"},
                applyUnitsImmediately: true
              },
              {
                addOnId: add_on_3.id,
                units: "30",
                chargeModel: "standard",
                properties: {amount: "1000.00"},
                applyUnitsImmediately: true
              },
              {
                addOnId: add_on_4.id,
                units: "40",
                chargeModel: "graduated",
                properties: {
                  graduatedRanges: [
                    {fromValue: 0, toValue: 10, perUnitAmount: "10.00", flatAmount: "0"},
                    {fromValue: 11, toValue: nil, perUnitAmount: "15.00", flatAmount: "100"}
                  ]
                }
              },
              {
                addOnId: add_on_5.id,
                units: "50",
                chargeModel: "volume",
                properties: {
                  volumeRanges: [
                    {fromValue: 0, toValue: nil, perUnitAmount: "10.00", flatAmount: "0"}
                  ]
                }
              }
            ]
          }
        }
      )

      result_data = result["data"]["updatePlan"]

      expect(result_data["fixedCharges"].count).to eq(5)

      expect(result_data["fixedCharges"].first["id"]).to eq(fixed_charge_1.id)
      expect(result_data["fixedCharges"].first["units"]).to eq("10")
      expect(result_data["fixedCharges"].first["properties"]["amount"]).to eq("10.00")
      expect(result_data["fixedCharges"].first["addOn"]["id"]).to eq(fixed_charge_1.add_on_id)

      expect(result_data["fixedCharges"].second["id"]).to eq(fixed_charge_2.id)
      expect(result_data["fixedCharges"].second["units"]).to eq("20.55")
      expect(result_data["fixedCharges"].second["properties"]["amount"]).to eq("100.00")
      expect(result_data["fixedCharges"].second["addOn"]["id"]).to eq(fixed_charge_2.add_on_id)

      expect(result_data["fixedCharges"].third["chargeModel"]).to eq("standard")
      expect(result_data["fixedCharges"].third["units"]).to eq("30")
      expect(result_data["fixedCharges"].third["properties"]["amount"]).to eq("1000.00")
      expect(result_data["fixedCharges"].third["addOn"]["id"]).to eq(add_on_3.id)
      expect(result_data["fixedCharges"].third["addOn"]["name"]).to eq(add_on_3.name)

      expect(result_data["fixedCharges"].fourth["chargeModel"]).to eq("graduated")
      expect(result_data["fixedCharges"].fourth["units"]).to eq("40")
      expect(result_data["fixedCharges"].fourth["properties"]["graduatedRanges"].count).to eq(2)
      expect(result_data["fixedCharges"].fourth["addOn"]["id"]).to eq(add_on_4.id)
      expect(result_data["fixedCharges"].fourth["addOn"]["name"]).to eq(add_on_4.name)

      expect(result_data["fixedCharges"].fifth["chargeModel"]).to eq("volume")
      expect(result_data["fixedCharges"].fifth["units"]).to eq("50")
      expect(result_data["fixedCharges"].fifth["properties"]["volumeRanges"].count).to eq(1)
      expect(result_data["fixedCharges"].fifth["addOn"]["id"]).to eq(add_on_5.id)
      expect(result_data["fixedCharges"].fifth["addOn"]["name"]).to eq(add_on_5.name)

      expect(FixedCharge.count).to eq(5)

      # NOTE: first fixed charge does not have event associated because units did not change
      # and subscription was created with factory and already activated.
      expect(FixedChargeEvent.count).to eq(4)

      fixed_charge_3 = plan.fixed_charges.find_by(add_on_id: add_on_3.id)
      fixed_charge_4 = plan.fixed_charges.find_by(add_on_id: add_on_4.id)
      fixed_charge_5 = plan.fixed_charges.find_by(add_on_id: add_on_5.id)

      expect(FixedChargeEvent.pluck(:fixed_charge_id, :timestamp, :units))
        .to contain_exactly(
          [fixed_charge_2.id, be_within(1.minute).of(Time.current), BigDecimal("20.55")],
          [fixed_charge_3.id, be_within(1.minute).of(Time.current), BigDecimal(30)],
          [fixed_charge_4.id, be_within(1.minute).of(1.month.from_now.beginning_of_month), BigDecimal(40)],
          [fixed_charge_5.id, be_within(1.minute).of(1.month.from_now.beginning_of_month), BigDecimal(50)]
        )
    end
  end

  context "when interval is yearly" do
    it "updates a plan with monthly billing for charges and fixed charges" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: plan.id,
            name: "Updated plan",
            code: "updated_plan",
            interval: "yearly",
            payInAdvance: true,
            amountCents: 200,
            amountCurrency: "EUR",
            billChargesMonthly: true,
            billFixedChargesMonthly: true,
            charges: []
          }
        }
      )

      result_data = result["data"]["updatePlan"]

      expect(result_data["billChargesMonthly"]).to be true
      expect(result_data["billFixedChargesMonthly"]).to be true
    end
  end

  context "with metadata" do
    let(:mutation) do
      <<~GQL
        mutation($input: UpdatePlanInput!) {
          updatePlan(input: $input) {
            id
            metadata { key value }
          }
        }
      GQL
    end

    before { create(:item_metadata, owner: plan, organization:, value: {"existing" => "value"}) }

    it "replaces metadata (not merges)" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: plan.id,
            name: "Updated plan",
            code: plan.code,
            interval: "monthly",
            payInAdvance: false,
            amountCents: 200,
            amountCurrency: "EUR",
            charges: [],
            metadata: [{key: "new", value: "data"}]
          }
        }
      )

      result_data = result["data"]["updatePlan"]
      expect(result_data["metadata"]).to eq([{"key" => "new", "value" => "data"}])
    end
  end
end
