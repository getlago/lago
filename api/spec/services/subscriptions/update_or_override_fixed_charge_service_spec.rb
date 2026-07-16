# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::UpdateOrOverrideFixedChargeService do
  subject(:service) { described_class.new(subscription:, fixed_charge:, params:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:add_on) { create(:add_on, organization:) }
  let(:subscription) { create(:subscription, customer:, plan:) }
  let(:fixed_charge) { create(:fixed_charge, plan:, organization:, add_on:) }
  let(:params) do
    {
      invoice_display_name: "Overridden Fixed Charge",
      units: "10"
    }
  end

  describe "#call" do
    context "without premium license" do
      it "returns forbidden failure" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
      end
    end

    context "with premium license", :premium do
      before do
        fixed_charge
        subscription
      end

      it "creates a plan override" do
        expect { service.call }.to change(Plan, :count).by(1)

        new_plan = subscription.reload.plan
        expect(new_plan.parent_id).to eq(plan.id)
      end

      it "creates fixed charge override via plan override" do
        expect { service.call }.to change(FixedCharge, :count).by(1)
      end

      it "returns the fixed charge override with parent_id" do
        result = service.call

        expect(result.fixed_charge.parent_id).to eq(fixed_charge.id)
      end

      it "assigns the fixed charge override to the new plan" do
        result = service.call

        expect(result.fixed_charge.plan_id).not_to eq(plan.id)
        expect(result.fixed_charge.plan.parent_id).to eq(plan.id)
      end

      it "updates the subscription to use the overridden plan" do
        service.call

        subscription.reload
        expect(subscription.plan.parent_id).to eq(plan.id)
      end

      it "applies the override params to the fixed charge" do
        result = service.call

        expect(result.fixed_charge.invoice_display_name).to eq("Overridden Fixed Charge")
        expect(result.fixed_charge.units).to eq(10)
      end

      context "when units is negative" do
        let(:params) { {units: "-1"} }

        it "returns a validation failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end

      context "when updating units with apply_units_immediately" do
        let(:params) do
          {
            invoice_display_name: "Overridden Fixed Charge",
            units: "10",
            apply_units_immediately: true
          }
        end

        context "with a pay in advance fixed charge" do
          let(:fixed_charge) { create(:fixed_charge, plan:, organization:, add_on:, pay_in_advance: true) }

          it "schedules a Invoices::CreatePayInAdvanceFixedChargesJob" do
            expect { service.call }.to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
          end

          context "when the subscription is payment-gated" do
            let(:subscription) { create(:subscription, :incomplete, customer:, plan:) }

            before { create(:subscription_activation_rule, subscription:, organization:, status: :pending) }

            it "does not schedule a Invoices::CreatePayInAdvanceFixedChargesJob" do
              expect { service.call }.not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
            end
          end
        end

        context "with a pay in arrears fixed charge" do
          it "does not schedule a Invoices::CreatePayInAdvanceFixedChargesJob" do
            expect { service.call }.not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
          end
        end
      end

      context "when apply_units_immediately is false" do
        let(:fixed_charge) { create(:fixed_charge, plan:, organization:, add_on:, pay_in_advance: true) }

        it "does not schedule a Invoices::CreatePayInAdvanceFixedChargesJob" do
          expect { service.call }.not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
        end
      end

      context "when units are not updated" do
        let(:fixed_charge) { create(:fixed_charge, plan:, organization:, add_on:, pay_in_advance: true) }
        let(:params) do
          {
            invoice_display_name: "Overridden Fixed Charge",
            apply_units_immediately: true
          }
        end

        it "does not schedule a Invoices::CreatePayInAdvanceFixedChargesJob" do
          expect { service.call }.not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
        end
      end

      context "when subscription is nil" do
        let(:subscription) { nil }

        it "returns not found failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.resource).to eq("subscription")
        end
      end

      context "when fixed_charge is nil" do
        let(:fixed_charge) { nil }

        it "returns not found failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.resource).to eq("fixed_charge")
        end
      end

      context "when subscription already has a plan override" do
        let(:overridden_plan) { create(:plan, organization:, parent: plan) }
        let(:subscription) { create(:subscription, customer:, plan: overridden_plan) }

        it "does not create a new plan" do
          expect { service.call }.not_to change(Plan, :count)
        end

        it "creates the fixed charge override on the existing overridden plan" do
          result = service.call

          expect(result.fixed_charge.plan_id).to eq(overridden_plan.id)
          expect(result.fixed_charge.parent_id).to eq(fixed_charge.id)
        end
      end

      context "when fixed charge override already exists" do
        let(:overridden_plan) { create(:plan, organization:, parent: plan) }
        let(:subscription) { create(:subscription, customer:, plan: overridden_plan) }
        let!(:existing_override) { create(:fixed_charge, plan: overridden_plan, organization:, add_on:, parent: fixed_charge, code: fixed_charge.code) }

        it "does not create a new fixed charge" do
          expect { service.call }.not_to change(FixedCharge, :count)
        end

        it "updates the existing fixed charge override" do
          result = service.call

          expect(result.fixed_charge.id).to eq(existing_override.id)
          expect(result.fixed_charge.invoice_display_name).to eq("Overridden Fixed Charge")
          expect(result.fixed_charge.units).to eq(10)
        end

        it "calls EmitEventsService" do
          allow(FixedCharges::EmitEventsService).to receive(:call!)

          service.call

          expect(FixedCharges::EmitEventsService).to have_received(:call!).with(
            fixed_charge: existing_override,
            subscription:,
            apply_units_immediately: false
          )
        end

        context "with apply_units_immediately param" do
          let(:params) do
            {
              invoice_display_name: "Overridden Fixed Charge",
              units: "10",
              apply_units_immediately: true
            }
          end

          it "calls EmitEventsService with apply_units_immediately true" do
            allow(FixedCharges::EmitEventsService).to receive(:call!)

            service.call

            expect(FixedCharges::EmitEventsService).to have_received(:call!).with(
              fixed_charge: existing_override,
              subscription:,
              apply_units_immediately: true
            )
          end
        end
      end

      context "when the fixed charge passed is itself an override" do
        let(:overridden_plan) { create(:plan, organization:, parent: plan) }
        let(:subscription) { create(:subscription, customer:, plan: overridden_plan) }
        let(:parent_fixed_charge) { create(:fixed_charge, plan:, organization:, add_on:) }
        let!(:fixed_charge) { create(:fixed_charge, plan: overridden_plan, organization:, add_on:, parent: parent_fixed_charge, code: parent_fixed_charge.code) }

        it "does not create a new fixed charge" do
          expect { service.call }.not_to change(FixedCharge, :count)
        end

        it "updates the existing fixed charge override" do
          result = service.call

          expect(result.fixed_charge.id).to eq(fixed_charge.id)
          expect(result.fixed_charge.invoice_display_name).to eq("Overridden Fixed Charge")
        end
      end

      context "with tax_codes" do
        let(:tax) { create(:tax, organization:) }
        let(:params) do
          {
            invoice_display_name: "Taxed Fixed Charge",
            tax_codes: [tax.code]
          }
        end

        it "applies taxes to the fixed charge override" do
          result = service.call

          expect(result.fixed_charge.taxes).to include(tax)
        end
      end

      context "with units-only params" do
        let(:fixed_charge) { create(:fixed_charge, plan:, organization:, add_on:, units: 5) }
        let(:params) { {units: "15"} }

        it "writes a Subscription::FixedChargeUnitsOverride for the (sub, fc) pair" do
          expect { service.call }
            .to change(::Subscription::FixedChargeUnitsOverride, :count).by(1)

          override = ::Subscription::FixedChargeUnitsOverride.find_by(subscription:, fixed_charge:)
          expect(override.units).to eq(15)
          expect(override.organization).to eq(subscription.organization)
        end

        it "does not create a plan override or a fixed_charge override" do
          expect { service.call }
            .to not_change(Plan, :count)
            .and not_change(FixedCharge, :count)
        end

        it "returns the parent fixed_charge in the result" do
          result = service.call

          expect(result).to be_success
          expect(result.fixed_charge).to eq(fixed_charge)
        end

        it "emits a fixed charge event with the override units" do
          service.call

          event = FixedChargeEvent.where(subscription:, fixed_charge:).order(:created_at).last
          expect(event.units).to eq(15)
        end

        context "when an override already exists" do
          before do
            create(:subscription_fixed_charge_units_override, subscription:, fixed_charge:, organization:, units: 7)
          end

          it "updates the existing override row instead of creating a new one" do
            expect { service.call }
              .not_to change(::Subscription::FixedChargeUnitsOverride, :count)

            override = ::Subscription::FixedChargeUnitsOverride.find_by(subscription:, fixed_charge:)
            expect(override.units).to eq(15)
          end
        end

        context "when apply_units_immediately is true on a pay_in_advance fixed_charge" do
          let(:fixed_charge) do
            create(:fixed_charge, plan:, organization:, add_on:, units: 5, pay_in_advance: true)
          end
          let(:params) { {units: "15", apply_units_immediately: true} }

          it "enqueues the pay-in-advance billing job for the subscription" do
            expect { service.call }
              .to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
              .with(subscription, kind_of(Integer))
          end
        end

        context "when apply_units_immediately is true but the fixed_charge is pay_in_arrears" do
          let(:params) { {units: "15", apply_units_immediately: true} }

          it "does not enqueue the pay-in-advance billing job" do
            expect { service.call }
              .not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
          end
        end

        context "when the subscription is already on an overridden plan" do
          let(:overridden_plan) { create(:plan, organization:, parent: plan) }
          let(:subscription) { create(:subscription, customer:, plan: overridden_plan) }

          it "falls through to the legacy plan-override path" do
            expect { service.call }
              .to not_change(::Subscription::FixedChargeUnitsOverride, :count)
              .and change(FixedCharge, :count).by(1)
          end
        end
      end

      context "when the subscription has existing units overrides and params trigger plan override" do
        let(:other_fixed_charge) { create(:fixed_charge, plan:, organization:, add_on:, units: 8) }
        let(:params) { {units: "15", tax_codes: [create(:tax, organization:).code]} }

        before do
          other_fixed_charge
          create(:subscription_fixed_charge_units_override, subscription:, fixed_charge:, organization:, units: 11)
          create(:subscription_fixed_charge_units_override, subscription:, fixed_charge: other_fixed_charge, organization:, units: 22)
        end

        it "discards the override rows and promotes their units onto the new fixed_charge overrides" do
          expect { service.call }
            .to change(Plan, :count).by(1)
            .and change(FixedCharge, :count).by(2)
            .and change { ::Subscription::FixedChargeUnitsOverride.kept.where(subscription:).count }.from(2).to(0)

          subscription.reload
          overridden_plan = subscription.plan
          expect(overridden_plan.parent_id).to eq(plan.id)

          # The fixed_charge the user updated reflects the user's units (15) plus its tax_codes
          fc_being_updated = overridden_plan.fixed_charges.find_sole_by(parent_id: fixed_charge.id)
          expect(fc_being_updated.units).to eq(15)

          # The other fixed_charge that had an override row now carries those units on its plan-override clone
          other_fc_overridden = overridden_plan.fixed_charges.find_sole_by(parent_id: other_fixed_charge.id)
          expect(other_fc_overridden.units).to eq(22)
        end
      end
    end
  end
end
