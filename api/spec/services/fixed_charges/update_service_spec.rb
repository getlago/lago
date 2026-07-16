# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedCharges::UpdateService do
  subject(:update_service) do
    described_class.new(fixed_charge:, params:, cascade_options:, timestamp:)
  end

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:add_on) { create(:add_on, organization:) }
  let(:timestamp) { Time.current.to_i }

  let(:fixed_charge) do
    create(:fixed_charge, plan:, add_on:, prorated: false, pay_in_advance: false, units: 10)
  end

  let(:cascade_options) { {cascade: false} }
  let(:params) do
    {
      charge_model: "standard",
      invoice_display_name: "Updated Display Name",
      units: 5,
      prorated: true,
      pay_in_advance: true,
      properties: {amount: "200"}
    }
  end

  describe "#call" do
    subject(:result) { update_service.call }

    context "when fixed_charge is missing" do
      let(:fixed_charge) { nil }

      it "returns a not found failure" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("fixed_charge_not_found")
      end
    end

    context "when updating code to one that already exists on the plan" do
      let(:params) do
        {
          charge_model: "standard",
          code: "taken_code",
          units: 10,
          properties: {amount: "100"}
        }
      end

      before do
        create(:fixed_charge, plan:, add_on:, code: "taken_code")
      end

      it "returns a validation failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq({code: ["value_already_exist"]})
      end
    end

    context "when fixed_charge exists" do
      it "updates the fixed charge without updating pay_in_advance and prorated" do
        expect(result).to be_success
        expect(result.fixed_charge).to have_attributes(
          charge_model: "standard",
          invoice_display_name: "Updated Display Name",
          units: 5,
          prorated: false,
          pay_in_advance: false,
          properties: {"amount" => "200"}
        )
      end

      context "when plan is attached to subscriptions" do
        before do
          create(:subscription, plan:)
        end

        it "does not update charge_model" do
          original_charge_model = fixed_charge.charge_model
          params[:charge_model] = "graduated"

          expect(result).to be_success
          expect(result.fixed_charge.charge_model).to eq(original_charge_model)
        end

        it "does not update code" do
          params[:code] = "updated_code"

          expect { result }.not_to change { fixed_charge.reload.code }
        end

        it "does not apply taxes" do
          tax = create(:tax, organization: plan.organization, code: "tax1")
          params[:tax_codes] = [tax.code]

          expect(result).to be_success
          expect(fixed_charge.reload.applied_taxes).to be_empty
        end
      end

      context "when plan is not attached to subscriptions" do
        it "updates charge_model" do
          params[:charge_model] = "graduated"
          params[:properties] = {
            graduated_ranges: [
              {
                from_value: 0,
                to_value: nil,
                per_unit_amount: "10",
                flat_amount: "0"
              }
            ]
          }

          expect(result).to be_success
          expect(result.fixed_charge.charge_model).to eq("graduated")
        end

        context "with code in the params" do
          before { params[:code] = "updated_code" }

          it "updates fixed charge code" do
            expect { result }.to change { fixed_charge.reload.code }.to("updated_code")
          end
        end

        context "when tax_codes are provided" do
          let(:tax1) { create(:tax, organization: plan.organization, code: "tax1") }
          let(:tax2) { create(:tax, organization: plan.organization, code: "tax2") }

          before do
            params[:tax_codes] = [tax1.code, tax2.code]
          end

          it "applies taxes to the fixed charge" do
            expect { result }.to change { fixed_charge.reload.applied_taxes.count }.from(0).to(2)
          end

          it "returns success" do
            expect(result).to be_success
          end
        end
      end

      context "when properties are not provided" do
        let(:params) do
          {
            charge_model: "standard",
            invoice_display_name: "Updated Display Name",
            units: 5,
            prorated: true
          }
        end

        it "uses default properties for the charge model" do
          expect(result).to be_success
          expect(result.fixed_charge.properties).to eq({"amount" => "0"})
        end
      end

      context "when cascade is true" do
        let(:cascade_options) { {cascade: true} }

        context "when charge_model is different" do
          before do
            params[:charge_model] = "graduated"
          end

          it "returns early without updating" do
            expect(result).to be_success
            expect(result.fixed_charge).to be_nil
          end
        end

        context "when charge_model is the same" do
          it "does not update the display name" do
            expect(result).to be_success
            expect(result.fixed_charge.invoice_display_name).not_to eq("Updated Display Name")
          end

          context "with code in the params" do
            before { params[:code] = "cascaded_code" }

            it "updates fixed charge code" do
              expect { result }.to change { fixed_charge.reload.code }.to("cascaded_code")
            end
          end

          context "when equal_properties is true" do
            let(:cascade_options) { {cascade: true, equal_properties: true} }

            it "updates properties and units" do
              expect(result).to be_success
              expect(result.fixed_charge.properties).to eq({"amount" => "200"})
              expect(result.fixed_charge.units).to eq(5)
            end
          end

          context "when equal_properties is false" do
            it "does not update properties nor units" do
              original_properties = fixed_charge.properties
              expect(result).to be_success
              expect(result.fixed_charge.properties).to eq(original_properties)
              expect(result.fixed_charge.units).to eq(10)
            end
          end
        end

        it "does not apply taxes" do
          tax = create(:tax, organization: plan.organization, code: "tax1")
          params[:tax_codes] = [tax.code]

          expect(result).to be_success
          expect(fixed_charge.reload.applied_taxes).to be_empty
        end
      end

      context "with validation errors" do
        let(:params) do
          {
            charge_model: "standard",
            units: -1 # Invalid units
          }
        end

        it "returns a validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end

      context "when tax service fails" do
        let(:params) do
          {
            charge_model: "standard",
            invoice_display_name: "Updated Display Name",
            units: 5,
            prorated: true,
            properties: {amount: "200"},
            tax_codes: ["non_existent_tax"]
          }
        end

        it "returns the tax service error" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.error_code).to eq("tax_not_found")
        end
      end

      context "when units have been changed" do
        let(:params) do
          {
            charge_model: "standard",
            apply_units_immediately: true,
            units: fixed_charge.units + 15,
            properties: {amount: "200"}
          }
        end

        before do
          allow(FixedCharges::EmitEventsService)
            .to receive(:call!)
        end

        it "emits fixed charge events for all active subscriptions" do
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

        context "when fixed charge is pay_in_advance" do
          let(:fixed_charge) do
            create(:fixed_charge, plan:, add_on:, prorated: false, pay_in_advance: true, units: 10)
          end

          let!(:subscription) { create(:subscription, plan:) }

          it "enqueues a single fan out billing job for the plan" do
            result

            expect(Invoices::CreateAllPayInAdvanceFixedChargesJob)
              .to have_been_enqueued
              .with(plan, timestamp, fixed_charge)
          end

          it "enqueues pay in advance billing job" do
            perform_enqueued_jobs(only: Invoices::CreateAllPayInAdvanceFixedChargesJob) { result }

            expect(Invoices::CreatePayInAdvanceFixedChargesJob)
              .to have_been_enqueued
              .with(subscription, timestamp)
          end

          context "when the subscription has a per-subscription units override" do
            let(:other_subscription) { create(:subscription, plan:) }

            before do
              other_subscription
              create(:subscription_fixed_charge_units_override,
                subscription:,
                fixed_charge:,
                organization:)
            end

            it "does not enqueue the billing job for the overridden subscription" do
              perform_enqueued_jobs(only: Invoices::CreateAllPayInAdvanceFixedChargesJob) { result }

              expect(Invoices::CreatePayInAdvanceFixedChargesJob)
                .not_to have_been_enqueued
                .with(subscription, timestamp)
            end

            it "still enqueues the billing job for other plan subscriptions" do
              perform_enqueued_jobs(only: Invoices::CreateAllPayInAdvanceFixedChargesJob) { result }

              expect(Invoices::CreatePayInAdvanceFixedChargesJob)
                .to have_been_enqueued
                .with(other_subscription, timestamp)
            end
          end
        end

        context "when apply_units_immediately is false" do
          let(:params) do
            {
              charge_model: "standard",
              apply_units_immediately: false,
              units: fixed_charge.units + 15,
              properties: {amount: "200"}
            }
          end

          it "emits fixed charge events for all active subscriptions" do
            result

            expect(FixedCharges::EmitEventsService)
              .to have_received(:call!)
              .with(
                fixed_charge: result.fixed_charge,
                apply_units_immediately: false,
                timestamp:
              )
              .once
          end

          it "does not enqueue pay in advance billing job" do
            result

            expect(Invoices::CreateAllPayInAdvanceFixedChargesJob)
              .not_to have_been_enqueued
          end
        end
      end

      context "when units does not change" do
        let(:params) do
          {
            charge_model: "standard",
            apply_units_immediately: true,
            units: fixed_charge.units,
            properties: {amount: "200"}
          }
        end

        before do
          allow(FixedCharges::EmitEventsService)
            .to receive(:call!)
        end

        it "does not emit any fixed charge events" do
          result

          expect(FixedCharges::EmitEventsService)
            .not_to have_received(:call!)
        end
      end

      context "with cascade_updates" do
        subject(:update_service) do
          described_class.new(fixed_charge:, params:, cascade_options:, timestamp:, cascade_updates: true)
        end

        let(:child_plan) { create(:plan, organization:, parent: plan) }
        let(:child_fixed_charge) { create(:fixed_charge, plan: child_plan, organization:, add_on:, parent: fixed_charge) }

        before do
          create(:subscription, plan: child_plan, status: :active)
          child_fixed_charge
          allow(FixedCharges::UpdateChildrenJob).to receive(:perform_later)
        end

        it "triggers cascade update via FixedCharges::UpdateChildrenJob" do
          result

          expect(FixedCharges::UpdateChildrenJob).to have_received(:perform_later).with(
            params: hash_including("charge_model", "properties", "units"),
            old_parent_attrs: hash_including("id" => fixed_charge.id)
          )
        end

        context "when fixed_charge has no children" do
          before { child_fixed_charge.update!(parent_id: nil) }

          it "does not trigger cascade update" do
            result

            expect(FixedCharges::UpdateChildrenJob).not_to have_received(:perform_later)
          end
        end
      end

      context "without cascade_updates when fixed_charge has children" do
        let(:child_plan) { create(:plan, organization:, parent: plan) }
        let(:child_fixed_charge) { create(:fixed_charge, plan: child_plan, organization:, add_on:, parent: fixed_charge) }

        before do
          create(:subscription, plan: child_plan, status: :active)
          child_fixed_charge
          allow(FixedCharges::UpdateChildrenJob).to receive(:perform_later)
        end

        it "does not trigger cascade update" do
          result

          expect(FixedCharges::UpdateChildrenJob).not_to have_received(:perform_later)
        end
      end
    end
  end
end
