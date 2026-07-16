# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charges::UpdateService do
  let(:update_service) { described_class.new(charge:, params:, cascade_options:, cascade_updates:) }
  let(:cascade_updates) { false }

  let(:plan) { create(:plan) }
  let(:organization) { plan.organization }
  let(:cascade_options) do
    {
      cascade: false
    }
  end

  describe "#call" do
    subject(:result) { update_service.call }

    context "when charge is missing" do
      let(:charge) { nil }
      let(:params) { {} }

      it "returns an error" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("charge_not_found")
      end
    end

    context "when updating code to one that already exists on the plan" do
      let(:sum_billable_metric) { create(:sum_billable_metric, organization:, recurring: true) }
      let(:charge) do
        create(:standard_charge, plan:, organization:, billable_metric: sum_billable_metric, code: "original_code")
      end
      let(:cascade_options) { {cascade: false} }
      let(:params) do
        {
          id: charge.id,
          billable_metric_id: sum_billable_metric.id,
          charge_model: "standard",
          code: "taken_code",
          properties: {amount: "100"}
        }
      end

      before do
        create(:standard_charge, plan:, organization:, billable_metric: sum_billable_metric, code: "taken_code")
      end

      it "returns a validation failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq({code: ["value_already_exist"]})
      end
    end

    context "when charge exists" do
      let(:sum_billable_metric) { create(:sum_billable_metric, organization:, recurring: true) }
      let(:charge) do
        create(
          :standard_charge,
          plan:,
          organization:,
          billable_metric_id: sum_billable_metric.id,
          amount_currency: "USD",
          properties: {
            amount: "300"
          }
        )
      end
      let(:billable_metric_filter) do
        create(
          :billable_metric_filter,
          billable_metric: sum_billable_metric,
          key: "payment_method",
          values: %w[card physical]
        )
      end
      let(:params) do
        {
          id: charge.id,
          billable_metric_id: sum_billable_metric.id,
          charge_model: "standard",
          pay_in_advance: true,
          prorated: true,
          invoiceable: false,
          accepts_target_wallet: true,
          properties: {
            amount: "400"
          }.merge(pricing_group_keys).merge(presentation_group_keys),
          applied_pricing_unit: applied_pricing_unit_params,
          filters: [
            {
              invoice_display_name: "Card filter",
              properties: {amount: "90"},
              values: {billable_metric_filter.key => ["card"]}
            }
          ]
        }
      end

      let(:applied_pricing_unit_params) do
        {
          conversion_rate: 2.5
        }
      end

      let(:presentation_group_keys) { {} }
      let(:pricing_group_keys) { {} }

      before { create(:applied_pricing_unit, pricing_unitable: charge, conversion_rate: 1.1) }

      it "updates existing charge" do
        subject

        expect(charge.reload).to have_attributes(
          prorated: true,
          properties: {"amount" => "400"}
        )

        expect(charge.filters.first).to have_attributes(
          invoice_display_name: "Card filter",
          properties: {"amount" => "90"}
        )
        expect(charge.filters.first.values.first).to have_attributes(
          billable_metric_filter_id: billable_metric_filter.id,
          values: ["card"]
        )
      end

      it "does not update premium attributes" do
        subject

        expect(charge.reload).to have_attributes(pay_in_advance: true, invoiceable: true, accepts_target_wallet: false)
      end

      context "when premium", :premium do
        it "saves premium attributes" do
          subject

          expect(charge.reload).to have_attributes(pay_in_advance: true, invoiceable: false)
        end

        context "with accepts_target_wallet" do
          context "when events_targeting_wallets is enabled" do
            before do
              charge.organization.update!(premium_integrations: ["events_targeting_wallets"])
            end

            it "updates accepts_target_wallet to true" do
              expect { subject }.to change { charge.reload.accepts_target_wallet }.from(false).to(true)
            end

            context "when accepts_target_wallet is false in params" do
              let(:params) do
                {
                  id: charge.id,
                  charge_model: "standard",
                  accepts_target_wallet: false,
                  properties: {amount: "400"}
                }
              end

              it "updates accepts_target_wallet to false" do
                charge.update!(accepts_target_wallet: true)

                expect { subject }.to change { charge.reload.accepts_target_wallet }.from(true).to(false)
              end
            end

            context "when accepts_target_wallet is nil in params" do
              let(:params) do
                {
                  id: charge.id,
                  charge_model: "standard",
                  properties: {amount: "400"}
                }
              end

              it "does not update accepts_target_wallet" do
                charge.update!(accepts_target_wallet: true)

                expect { subject }.not_to change { charge.reload.accepts_target_wallet }
              end
            end
          end

          context "when events_targeting_wallets is not enabled" do
            it "does not update accepts_target_wallet" do
              expect { subject }.not_to change { charge.reload.accepts_target_wallet }
            end
          end
        end
      end

      context "with code in the params" do
        let(:params) do
          {
            id: charge.id,
            charge_model: "standard",
            code: "updated_code",
            properties: {amount: "400"}
          }
        end

        it "updates charge code" do
          expect { subject }.to change { charge.reload.code }.to("updated_code")
        end

        context "when plan is attached to subscriptions" do
          before { create(:subscription, plan:) }

          it "does not update charge code" do
            expect { subject }.not_to change { charge.reload.code }
          end
        end
      end

      context "when cascade is true" do
        let(:cascade_options) do
          {
            cascade: true,
            equal_properties: true,
            equal_applied_pricing_unit_rate: true
          }
        end

        it "updates charge properties" do
          subject

          expect(charge.reload).to have_attributes(properties: {"amount" => "400"})
        end

        it "does not cascade filters via this service" do
          # Filters in cascade mode are dispatched per-filter via
          # ChargeFilters::CascadeJob — they must not be processed here.
          allow(ChargeFilters::CreateOrUpdateBatchService).to receive(:call)

          subject

          expect(ChargeFilters::CreateOrUpdateBatchService).not_to have_received(:call)
        end

        it "updates applied pricing unit's conversion rate" do
          expect { subject }.to change(charge.applied_pricing_unit, :conversion_rate).to(2.5)
        end

        context "with code in the params" do
          let(:params) do
            {
              id: charge.id,
              charge_model: "standard",
              code: "new_charge_code",
              properties: {amount: "400"}
            }
          end

          it "updates charge code" do
            expect { subject }.to change { charge.reload.code }.to("new_charge_code")
          end
        end

        context "with presentation_group_keys in the properties" do
          let(:presentation_group_keys) do
            {presentation_group_keys: [{"value" => "region", "options" => {"display_in_invoice" => true}}]}
          end

          it "apply the value to the charge" do
            expect { subject }.to change { charge.reload.properties["presentation_group_keys"] }
              .from(nil).to([{"value" => "region", "options" => {"display_in_invoice" => true}}])
          end
        end

        context "with pricing_group_keys in the properties" do
          let(:pricing_group_keys) { {pricing_group_keys: ["cloud"]} }

          it "apply the value to the charge" do
            expect { subject }.to change { charge.reload.pricing_group_keys }
              .from(nil).to(["cloud"])
          end
        end

        context "with charge properties already overridden" do
          let(:cascade_options) do
            {
              cascade: true,
              equal_properties: false
            }
          end

          it "does not update charge properties" do
            expect { subject }.not_to change { charge.reload.properties }
          end

          context "with presentation_group_keys in the properties" do
            let(:presentation_group_keys) do
              {presentation_group_keys: [{"value" => "region", "options" => {"display_in_invoice" => true}}]}
            end

            it "apply the value to the charge" do
              expect { subject }.to change { charge.reload.properties["presentation_group_keys"] }
                .from(nil).to([{"value" => "region", "options" => {"display_in_invoice" => true}}])
            end

            context "when charge has a presentation_group_keys" do
              let(:charge) do
                create(
                  :standard_charge,
                  plan:,
                  billable_metric_id: sum_billable_metric.id,
                  amount_currency: "USD",
                  properties: {
                    amount: "300",
                    presentation_group_keys: [{value: "department"}]
                  }
                )
              end

              it "overrides the keys" do
                expect { subject }.to change { charge.reload.properties["presentation_group_keys"] }
                  .from([{"value" => "department"}])
                  .to([{"value" => "region", "options" => {"display_in_invoice" => true}}])
              end
            end
          end

          context "with pricing_group_keys in the properties" do
            let(:pricing_group_keys) { {pricing_group_keys: ["cloud"]} }

            it "apply the value to the charge" do
              expect { subject }.to change { charge.reload.pricing_group_keys }
                .from(nil).to(["cloud"])
            end

            context "when charge has a pricing_group_keys" do
              let(:charge) do
                create(
                  :standard_charge,
                  plan:,
                  billable_metric_id: sum_billable_metric.id,
                  amount_currency: "USD",
                  properties: {
                    amount: "300",
                    pricing_group_keys: ["region"]
                  }
                )
              end

              it "overrides the keys" do
                expect { subject }.to change { charge.reload.pricing_group_keys }
                  .from(["region"]).to(["cloud"])
              end
            end
          end

          context "with legacy grouped_by in the properties" do
            let(:pricing_group_keys) { {grouped_by: ["cloud"]} }

            it "apply the value to the charge" do
              expect { subject }.to change { charge.reload.pricing_group_keys }
                .from(nil).to(["cloud"])
            end

            context "when charge has a grouped_by" do
              let(:charge) do
                create(
                  :standard_charge,
                  plan:,
                  billable_metric_id: sum_billable_metric.id,
                  amount_currency: "USD",
                  properties: {
                    amount: "300",
                    grouped_by: ["region"]
                  }
                )
              end

              it "overrides the keys" do
                expect { subject }.to change { charge.reload.pricing_group_keys }
                  .from(["region"]).to(["cloud"])
              end
            end
          end
        end

        context "when applied pricing unit params are invalid" do
          let(:applied_pricing_unit_params) do
            {
              conversion_rate: -1
            }
          end

          it "fails with a validation error" do
            expect(result).to be_failure
            expect(result.error.messages).to match(conversion_rate: ["value_is_out_of_range"])
          end

          it "does not update applied pricing unit's conversion rate" do
            expect { subject }.not_to change { charge.applied_pricing_unit.reload.conversion_rate }
          end
        end
      end

      context "with cascade_updates" do
        let(:cascade_updates) { true }
        let(:child_plan) { create(:plan, organization:, parent: plan) }
        let(:child_charge) { create(:standard_charge, plan: child_plan, organization:, billable_metric: sum_billable_metric, parent: charge) }

        before do
          create(:subscription, plan: child_plan, status: :active)
          child_charge
          allow(Charges::UpdateChildrenJob).to receive(:perform_later)
        end

        it "triggers charge-level cascade via Charges::UpdateChildrenJob (without filters)" do
          subject

          expect(Charges::UpdateChildrenJob).to have_received(:perform_later) do |args|
            expect(args[:params]).to include("charge_model", "properties")
            expect(args[:params]).not_to have_key("filters")
            expect(args[:old_parent_attrs]).to include("id" => charge.id)
            expect(args).not_to have_key(:old_parent_filters_attrs)
          end
        end

        context "when charge has no children" do
          before { child_charge.update!(parent_id: nil) }

          it "does not trigger cascade update" do
            subject

            expect(Charges::UpdateChildrenJob).not_to have_received(:perform_later)
          end
        end
      end

      context "without cascade_updates when charge has children" do
        let(:child_plan) { create(:plan, organization:, parent: plan) }
        let(:child_charge) { create(:standard_charge, plan: child_plan, organization:, billable_metric: sum_billable_metric, parent: charge) }

        before do
          create(:subscription, plan: child_plan, status: :active)
          child_charge
          allow(Charges::UpdateChildrenJob).to receive(:perform_later)
        end

        it "does not trigger cascade update" do
          subject

          expect(Charges::UpdateChildrenJob).not_to have_received(:perform_later)
        end
      end
    end
  end
end
