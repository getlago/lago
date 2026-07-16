# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedCharges::CreateService do
  subject(:create_service) { described_class.new(plan:, params:) }

  let(:plan) { create(:plan) }
  let(:organization) { plan.organization }
  let(:add_on) { create(:add_on, organization:) }

  describe "#call" do
    subject(:result) { create_service.call }

    context "when plan is not found" do
      let(:plan) { nil }
      let(:params) { {} }

      it "returns a failure" do
        expect(result).to be_a_failure
        expect(result.error.error_code).to eq("plan_not_found")
      end
    end

    context "when plan exists" do
      context "when add_on is not found" do
        let(:params) do
          {
            add_on_id: "non-existing-id",
            charge_model: "standard"
          }
        end

        it "returns a failure" do
          expect(result).to be_a_failure
          expect(result.error.error_code).to eq("add_on_not_found")
        end

        it "does not create fixed charge" do
          expect { subject }.not_to change(FixedCharge, :count)
        end
      end

      context "when add_on_code is not found" do
        let(:params) do
          {
            add_on_code: "non-existing-code",
            charge_model: "standard"
          }
        end

        it "returns a failure" do
          expect(result).to be_a_failure
          expect(result.error.error_code).to eq("add_on_not_found")
        end

        it "does not create fixed charge" do
          expect { subject }.not_to change(FixedCharge, :count)
        end
      end

      context "when a fixed charge with the same code already exists on the plan" do
        let(:params) do
          {
            add_on_id: add_on.id,
            code: "existing_code",
            charge_model: "standard",
            properties: {amount: "100"}
          }
        end

        before do
          create(:fixed_charge, plan:, add_on:, code: "existing_code")
        end

        it "returns a validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages).to eq({code: ["value_already_exist"]})
        end
      end

      context "when params are invalid" do
        let(:params) do
          {add_on_id: add_on.id}
        end

        it "returns a failure" do
          expect(result).to be_a_failure
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end

        it "does not create fixed charge" do
          expect { subject }.not_to change(FixedCharge, :count)
        end
      end

      context "when params are valid" do
        let(:parent_fixed_charge) { create(:fixed_charge, plan:, add_on:) }
        let(:tax1) { create(:tax, organization:, code: "tax1") }
        let(:tax2) { create(:tax, organization:, code: "tax2") }

        before do
          parent_fixed_charge
        end

        context "when using add_on_id" do
          let(:params) do
            {
              add_on_id: add_on.id,
              code: "my_fixed_charge_code",
              charge_model: "standard",
              pay_in_advance: true,
              prorated: true,
              units: 5,
              invoice_display_name: "Custom Display Name",
              parent_id: parent_fixed_charge.id,
              properties: {amount: "100"},
              tax_codes: [tax1.code, tax2.code]
            }
          end

          it "creates new fixed charge" do
            expect { subject }.to change(FixedCharge, :count).by(1)
          end

          it "sets correctly attributes" do
            expect(result.fixed_charge).to have_attributes(
              organization_id: organization.id,
              plan_id: plan.id,
              add_on_id: add_on.id,
              code: "my_fixed_charge_code",
              charge_model: "standard",
              pay_in_advance: true,
              prorated: true,
              units: 5,
              invoice_display_name: "Custom Display Name",
              parent_id: parent_fixed_charge.id,
              properties: {"amount" => "100"}
            )
          end

          it "applies taxes when tax_codes are provided" do
            expect { subject }.to change(FixedCharge::AppliedTax, :count).by(2)

            expect(result.fixed_charge.taxes.pluck(:code)).to match_array([tax1.code, tax2.code])
          end

          it "returns success result" do
            expect(result).to be_success
            expect(result.fixed_charge).to be_persisted
          end
        end

        context "when using add_on_code" do
          let(:params) do
            {
              add_on_code: add_on.code,
              code: "add_on_code_fixed_charge",
              charge_model: "graduated",
              pay_in_advance: false,
              prorated: false,
              units: 10
            }
          end

          it "creates new fixed charge" do
            expect { subject }.to change(FixedCharge, :count).by(1)
          end

          it "sets correctly attributes" do
            expect(result.fixed_charge).to have_attributes(
              add_on_id: add_on.id,
              charge_model: "graduated",
              pay_in_advance: false,
              prorated: false,
              units: 10
            )
          end
        end

        context "when providing both add_on_id and add_on_code" do
          let(:other_add_on) { create(:add_on, organization:) }
          let(:params) do
            {
              add_on_id: add_on.id,
              add_on_code: other_add_on.code,
              code: "both_ids_fixed_charge",
              charge_model: "standard"
            }
          end

          it "prioritizes add_on_id over add_on_code" do
            expect(result.fixed_charge.add_on_id).to eq(add_on.id)
          end
        end

        context "when no properties are provided" do
          let(:params) do
            {
              add_on_id: add_on.id,
              code: "no_props_fixed_charge",
              charge_model: "standard"
            }
          end

          it "applies default properties" do
            expect(result.fixed_charge.properties).to eq({"amount" => "0"})
          end
        end

        context "when properties are provided" do
          let(:params) do
            {
              add_on_id: add_on.id,
              code: "graduated_fixed_charge",
              charge_model: "graduated",
              properties: {
                graduated_ranges: [
                  {
                    from_value: 0,
                    to_value: 10,
                    per_unit_amount: "2",
                    flat_amount: "5"
                  },
                  {
                    from_value: 11,
                    to_value: nil,
                    per_unit_amount: "1.5",
                    flat_amount: "0"
                  }
                ]
              }
            }
          end

          it "uses provided properties" do
            expect(result.fixed_charge.properties).to eq({
              "graduated_ranges" => [
                {
                  "from_value" => 0,
                  "to_value" => 10,
                  "per_unit_amount" => "2",
                  "flat_amount" => "5"
                },
                {
                  "from_value" => 11,
                  "to_value" => nil,
                  "per_unit_amount" => "1.5",
                  "flat_amount" => "0"
                }
              ]
            })
          end
        end

        context "when no tax_codes are provided" do
          let(:params) do
            {
              add_on_id: add_on.id,
              code: "no_tax_fixed_charge",
              charge_model: "standard"
            }
          end

          it "does not apply any taxes" do
            expect { subject }.not_to change(FixedCharge::AppliedTax, :count)
          end
        end

        context "when tax application fails" do
          let(:params) do
            {
              add_on_id: add_on.id,
              code: "tax_fail_fixed_charge",
              charge_model: "standard",
              tax_codes: ["non-existing-tax"]
            }
          end

          it "rolls back the transaction" do
            expect { subject }.not_to change(FixedCharge, :count)
          end

          it "returns failure result" do
            expect(result).to be_a_failure
            expect(result.error.error_code).to eq("tax_not_found")
          end
        end

        context "with default values" do
          let(:params) do
            {
              add_on_id: add_on.id,
              code: "defaults_fixed_charge",
              charge_model: "volume"
            }
          end

          it "sets default values for optional attributes" do
            expect(result.fixed_charge).to have_attributes(
              pay_in_advance: false,
              prorated: false,
              units: 0,
              invoice_display_name: nil,
              parent_id: nil
            )
          end
        end

        context "when add_on belongs to different organization" do
          let(:other_organization) { create(:organization) }
          let(:other_add_on) { create(:add_on, organization: other_organization) }
          let(:params) do
            {
              add_on_id: other_add_on.id,
              charge_model: "standard"
            }
          end

          it "returns a failure" do
            expect(result).to be_a_failure
            expect(result.error.error_code).to eq("add_on_not_found")
          end
        end

        context "when filtering properties with complex charge model" do
          let(:params) do
            {
              add_on_id: add_on.id,
              code: "filter_props_fixed_charge",
              charge_model: "volume",
              properties: {
                volume_ranges: [
                  {
                    from_value: 0,
                    to_value: nil,
                    per_unit_amount: "1.5",
                    flat_amount: "10"
                  }
                ],
                invalid_property: "should_be_filtered_out"
              }
            }
          end

          it "filters out invalid properties" do
            expect(result.fixed_charge.properties.keys).to eq(["volume_ranges"])
            expect(result.fixed_charge.properties["invalid_property"]).to be_nil
          end
        end

        context "when apply_units_immediately is true" do
          let(:params) do
            {
              add_on_id: add_on.id,
              code: "apply_immediately_fixed_charge",
              charge_model: "standard",
              apply_units_immediately: true
            }
          end

          before do
            allow(FixedCharges::EmitEventsService)
              .to receive(:call!)
          end

          it "creates new fixed charge" do
            expect { result }.to change(FixedCharge, :count).by(1)

            expect(result).to be_success
            expect(result.fixed_charge).to be_persisted
          end

          it "emits fixed charge events for all active subscriptions" do
            result

            expect(FixedCharges::EmitEventsService)
              .to have_received(:call!)
              .with(
                fixed_charge: result.fixed_charge,
                apply_units_immediately: true,
                timestamp: be_within(1.second).of(Time.current.to_i)
              )
              .once
          end
        end

        context "when apply_units_immediately is false" do
          let(:params) do
            {
              add_on_id: add_on.id,
              code: "no_apply_immediately_fixed_charge",
              charge_model: "standard",
              apply_units_immediately: false
            }
          end

          before do
            allow(FixedCharges::EmitEventsService)
              .to receive(:call!)
          end

          it "creates new fixed charge" do
            expect { result }.to change(FixedCharge, :count).by(1)
            expect(result).to be_success
            expect(result.fixed_charge).to be_persisted
          end

          it "emits fixed charge events for active subscriptions with apply_units_immediately false" do
            result

            expect(FixedCharges::EmitEventsService)
              .to have_received(:call!)
              .with(
                fixed_charge: result.fixed_charge,
                apply_units_immediately: false,
                timestamp: be_within(1.second).of(Time.current.to_i)
              )
              .once
          end
        end
      end
    end

    context "when timestamp is provided" do
      subject(:create_service) { described_class.new(plan:, params:, timestamp:) }

      let(:timestamp) { 2.days.ago.to_i }
      let(:params) do
        {
          add_on_id: add_on.id,
          code: "timestamp_fixed_charge",
          charge_model: "standard",
          units: 5,
          properties: {amount: "100"},
          apply_units_immediately: true
        }
      end

      before do
        allow(FixedCharges::EmitEventsService)
          .to receive(:call!)
          .and_call_original
      end

      it "passes the custom timestamp to EmitEventsService" do
        result

        expect(FixedCharges::EmitEventsService)
          .to have_received(:call!)
          .with(
            fixed_charge: result.fixed_charge,
            apply_units_immediately: true,
            timestamp:
          )
          .once
      end
    end
  end
end
