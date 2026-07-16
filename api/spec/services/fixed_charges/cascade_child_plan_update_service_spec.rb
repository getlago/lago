# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedCharges::CascadeChildPlanUpdateService do
  subject(:result) { described_class.call(plan:, cascade_fixed_charges_payload:, timestamp:) }

  let(:organization) { create(:organization) }
  let(:parent_plan) { create(:plan, organization:) }
  let(:plan) { create(:plan, organization:, parent: parent_plan) }
  let(:add_on) { create(:add_on, organization:) }
  let(:timestamp) { Time.current.to_i }
  let(:subscription) { create(:subscription, :pending, plan:) }
  let(:parent_fixed_charge) { create(:fixed_charge, plan: parent_plan, add_on:, units: new_units) }
  let(:new_units) { 5 }
  let(:cascade_fixed_charges_payload) { [] }

  before do
    subscription

    allow(FixedCharges::CreateService).to receive(:call!).and_call_original
    allow(FixedCharges::UpdateService).to receive(:call!).and_call_original
  end

  describe "adding fixed charges" do
    let(:cascade_fixed_charges_payload) do
      [
        {
          action: :create,
          parent_id: parent_fixed_charge.id,
          code: parent_fixed_charge.code,
          add_on_id: add_on.id,
          charge_model: "standard",
          units: new_units,
          properties: {amount: "100"},
          invoice_display_name: "Test Fixed Charge",
          pay_in_advance: true,
          prorated: false,
          apply_units_immediately: true
        }
      ]
    end

    it "calls create service with correct parameters" do
      result

      expect(FixedCharges::CreateService).to have_received(:call!).with(
        plan:,
        params: cascade_fixed_charges_payload.first,
        timestamp:
      )
    end

    it "creates a new fixed charge for the plan" do
      expect { result }.to change(plan.fixed_charges, :count).by(1)
    end

    it "returns success result" do
      result

      expect(result).to be_success
      expect(result.plan).to eq(plan)
    end

    it "does not schedule invoice creation jobs for pay in advance fixed charges" do
      perform_enqueued_jobs(only: Invoices::CreateAllPayInAdvanceFixedChargesJob) { result }

      expect(Invoices::CreatePayInAdvanceFixedChargesJob).not_to have_been_enqueued
    end

    context "when plan has active subscriptions" do
      let(:subscription) { create(:subscription, :active, plan:) }

      it "schedules invoice creation jobs for each active subscription" do
        perform_enqueued_jobs(only: Invoices::CreateAllPayInAdvanceFixedChargesJob) { result }

        expect(Invoices::CreatePayInAdvanceFixedChargesJob)
          .to have_been_enqueued
          .with(subscription, timestamp)
      end
    end

    context "when plan has an incomplete subscription" do
      let(:subscription) { create(:subscription, :incomplete, plan:) }

      it "creates a fixed charge event for the incomplete subscription" do
        expect { result }.to change(subscription.fixed_charge_events, :count).by(1)
      end

      it "does not schedule invoice creation jobs" do
        expect { result }.not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
      end
    end

    context "when plan has active subscriptions but no pay in advance fixed charges" do
      let(:subscription) { create(:subscription, :active, plan:) }
      let(:cascade_fixed_charges_payload) do
        [
          {
            action: :create,
            parent_id: parent_fixed_charge.id,
            code: parent_fixed_charge.code,
            add_on_id: add_on.id,
            charge_model: "standard",
            units: new_units,
            properties: {amount: "100"},
            invoice_display_name: "Test Fixed Charge",
            pay_in_advance: false,
            prorated: false,
            apply_units_immediately: true
          }
        ]
      end

      it "does not schedule invoice creation jobs" do
        expect { result }.not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
      end
    end

    context "when fixed charge creation fails" do
      before do
        allow(FixedCharges::CreateService)
          .to receive(:call!)
          .and_raise(BaseService::FailedResult.new(BaseService::Result.new, "Failed to create fixed charge"))
      end

      it "returns failed result" do
        expect(result).to be_failure
      end
    end
  end

  describe "updating fixed charges" do
    let(:parent_fixed_charge) do
      create(
        :fixed_charge,
        :pay_in_advance,
        plan: parent_plan,
        add_on:,
        units: new_units,
        properties: {amount: "25"},
        charge_model: "standard"
      )
    end

    let(:existing_fixed_charge) do
      create(
        :fixed_charge,
        :pay_in_advance,
        plan:,
        add_on:,
        parent: parent_fixed_charge,
        units: parent_fixed_charge.units,
        properties: parent_fixed_charge.properties,
        charge_model: parent_fixed_charge.charge_model
      )
    end

    let(:cascade_fixed_charges_payload) do
      [
        {
          action: :update,
          id: parent_fixed_charge.id,
          add_on_id: add_on.id,
          charge_model: "standard",
          units: 10,
          properties: {amount: "100"},
          invoice_display_name: "Test Fixed Charge",
          pay_in_advance: true,
          prorated: false,
          apply_units_immediately: true,
          old_parent_attrs: parent_fixed_charge.attributes.merge(units: 5).deep_symbolize_keys
        }
      ]
    end

    before { existing_fixed_charge }

    it "returns success result" do
      result

      expect(result).to be_success
      expect(result.plan).to eq(plan)
    end

    it "calls update service with correct params and cascade options" do
      result

      expect(FixedCharges::UpdateService).to have_received(:call!).with(
        fixed_charge: existing_fixed_charge,
        params: cascade_fixed_charges_payload.first,
        timestamp:,
        cascade_options: {
          cascade: true,
          equal_properties: true
        },
        trigger_billing: false
      )
    end

    it "updates the existing fixed charge for the plan" do
      result

      expect(existing_fixed_charge.reload).to have_attributes(
        units: 10,
        properties: {"amount" => "100"}
      )
    end

    it "does not schedule invoice creation jobs for pay in advance fixed charges" do
      perform_enqueued_jobs(only: Invoices::CreateAllPayInAdvanceFixedChargesJob) { result }

      expect(Invoices::CreatePayInAdvanceFixedChargesJob).not_to have_been_enqueued
    end

    context "when plan has active subscriptions" do
      let(:subscription) { create(:subscription, :active, plan:) }

      it "schedules invoice creation jobs for each active subscription" do
        perform_enqueued_jobs(only: Invoices::CreateAllPayInAdvanceFixedChargesJob) { result }

        expect(Invoices::CreatePayInAdvanceFixedChargesJob)
          .to have_been_enqueued
          .with(subscription, timestamp)
      end
    end

    context "when plan has an incomplete subscription" do
      let(:subscription) { create(:subscription, :incomplete, plan:) }

      it "creates a fixed charge event for the incomplete subscription" do
        expect { result }.to change(subscription.fixed_charge_events, :count).by(1)
      end

      it "does not schedule invoice creation jobs" do
        expect { result }.not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
      end
    end

    context "when plan has active subscriptions but no pay in advance fixed charges" do
      let(:subscription) { create(:subscription, :active, plan:) }
      let(:existing_fixed_charge) do
        create(
          :fixed_charge,
          plan:,
          add_on:,
          parent: parent_fixed_charge,
          charge_model: "standard",
          units: 33,
          properties: {amount: "10"}
        )
      end

      it "does not schedule invoice creation jobs" do
        expect { result }.not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
      end
    end

    context "when fixed charge update fails" do
      before do
        allow(FixedCharges::UpdateService)
          .to receive(:call!)
          .and_raise(BaseService::FailedResult.new(BaseService::Result.new, "Failed to update fixed charge"))
      end

      it "returns failed result" do
        expect(result).to be_failure
      end
    end

    context "when fixed charge was overriden" do
      let(:existing_fixed_charge) do
        create(
          :fixed_charge,
          plan:,
          add_on:,
          parent: parent_fixed_charge,
          charge_model: "standard",
          units: 33,
          properties: {amount: "10"}
        )
      end

      let(:cascade_fixed_charges_payload) do
        [{
          action: :update,
          id: parent_fixed_charge.id,
          add_on_id: add_on.id,
          charge_model: "standard",
          units: new_units,
          properties: {amount: "50"},
          old_parent_attrs: parent_fixed_charge.attributes.merge(units: 99).deep_symbolize_keys
        }]
      end

      it "passes equal_properties: false to update service" do
        result

        expect(FixedCharges::UpdateService).to have_received(:call!).with(
          fixed_charge: existing_fixed_charge,
          params: cascade_fixed_charges_payload.first,
          timestamp:,
          cascade_options: {
            cascade: true,
            equal_properties: false
          },
          trigger_billing: false
        )
      end
    end

    context "when fixed charge is not found" do
      let(:cascade_fixed_charges_payload) do
        [{
          action: :update,
          id: "invalid_id"
        }]
      end

      it "returns not found failure" do
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("fixed_charge_not_found")
      end
    end
  end

  describe "processing multiple fixed charges in the payload" do
    let(:add_on_2) { create(:add_on, organization:) }

    let(:parent_fixed_charge_1) do
      create(
        :fixed_charge,
        :pay_in_advance,
        plan: parent_plan,
        add_on:,
        units: new_units,
        properties: {amount: "25"},
        charge_model: "standard"
      )
    end

    let(:parent_fixed_charge_2) do
      create(
        :fixed_charge,
        plan: parent_plan,
        add_on: add_on_2,
        units: new_units,
        properties: {amount: "55"},
        charge_model: "standard"
      )
    end

    let(:existing_fixed_charge_2) do
      create(
        :fixed_charge,
        :pay_in_advance,
        plan:,
        add_on: add_on_2,
        parent: parent_fixed_charge_2,
        units: parent_fixed_charge_2.units,
        properties: parent_fixed_charge_2.properties,
        charge_model: parent_fixed_charge_2.charge_model
      )
    end

    let(:cascade_fixed_charges_payload) do
      [
        {
          action: :create,
          parent_id: parent_fixed_charge.id,
          code: parent_fixed_charge.code,
          add_on_id: add_on.id,
          charge_model: "standard",
          units: new_units,
          properties: {amount: "100"},
          invoice_display_name: "Test Fixed Charge",
          pay_in_advance: true,
          prorated: false,
          apply_units_immediately: true
        },
        {
          action: :update,
          id: parent_fixed_charge_2.id,
          add_on_id: add_on.id,
          charge_model: "standard",
          units: new_units,
          properties: {amount: "100"},
          invoice_display_name: "Test Fixed Charge",
          pay_in_advance: true,
          prorated: false,
          apply_units_immediately: true,
          old_parent_attrs: parent_fixed_charge_2.attributes.merge(units: 5).deep_symbolize_keys
        }
      ]
    end

    before { existing_fixed_charge_2 }

    it "calls both create and update services" do
      result

      expect(FixedCharges::CreateService).to have_received(:call!).with(
        plan:,
        params: cascade_fixed_charges_payload.first,
        timestamp:
      )

      expect(FixedCharges::UpdateService).to have_received(:call!).with(
        fixed_charge: existing_fixed_charge_2,
        params: cascade_fixed_charges_payload.last,
        timestamp:,
        cascade_options: {
          cascade: true,
          equal_properties: true
        },
        trigger_billing: false
      )
    end
  end

  context "with an unknown action" do
    let(:cascade_fixed_charges_payload) do
      [
        {
          action: :create,
          parent_id: parent_fixed_charge.id,
          code: parent_fixed_charge.code,
          add_on_id: add_on.id,
          charge_model: "standard",
          units: 10,
          properties: {amount: "100"},
          invoice_display_name: "Test Fixed Charge",
          pay_in_advance: true,
          prorated: false,
          apply_units_immediately: true
        },
        {
          action: :invalid_action,
          parent_id: create(:fixed_charge, plan: parent_plan).id,
          add_on_id: add_on.id,
          charge_model: "standard",
          units: 10,
          properties: {amount: "100"},
          invoice_display_name: "Another Test Fixed Charge",
          pay_in_advance: true,
          prorated: false,
          apply_units_immediately: true
        }
      ]
    end

    it "raises an error with the unknown action" do
      expect(result).to be_failure
      expect(result.error).to eq("Unknown action invalid_action for fixed charge cascade")
    end

    it "does not create any fixed charges" do
      expect { result }.not_to change { plan.fixed_charges.count }
    end

    it "does not schedule invoice creation jobs for pay in advance fixed charges" do
      expect { result }.not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
    end
  end

  context "with empty payload" do
    let(:cascade_fixed_charges_payload) { [] }

    it "returns success result without creating or updating anything" do
      expect { result }.not_to change { plan.fixed_charges.count }
      expect(result).to be_success
    end

    it "schedules invoice jobs if active subscriptions exist" do
      create(:fixed_charge, plan:, pay_in_advance: true)
      create(:subscription, :active, plan:)

      expect { result }.not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
    end
  end
end
