# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeFilters::DestroyService do
  subject(:service) { described_class.call(charge_filter:) }

  let(:charge) { create(:standard_charge) }
  let(:charge_filter) { create(:charge_filter, charge:) }

  let(:card_location_filter) do
    create(
      :billable_metric_filter,
      billable_metric: charge.billable_metric,
      key: "card_location",
      values: %w[domestic international]
    )
  end

  describe "#call" do
    context "when charge_filter is nil" do
      subject(:service) { described_class.call(charge_filter: nil) }

      it "returns not found failure" do
        expect(service).not_to be_success
        expect(service.error).to be_a(BaseService::NotFoundFailure)
        expect(service.error.resource).to eq("charge_filter")
      end
    end

    context "with valid charge_filter" do
      let(:filter_value) do
        create(:charge_filter_value, charge_filter:, billable_metric_filter: card_location_filter, values: ["domestic"])
      end

      before { filter_value }

      it "soft deletes the charge filter" do
        expect { service }.to change { charge_filter.reload.discarded? }.from(false).to(true)
        expect(service).to be_success
        expect(service.charge_filter).to eq(charge_filter)
      end

      it "soft deletes the charge filter values" do
        expect { service }.to change { filter_value.reload.discarded? }.from(false).to(true)
      end

      it "returns the discarded charge filter" do
        result = service
        expect(result.charge_filter.deleted_at).to be_present
      end
    end

    context "with cascade_updates" do
      subject(:service) { described_class.call(charge_filter:, cascade_updates: true) }

      let(:child_plan) { create(:plan, organization: charge.organization, parent: charge.plan) }
      let(:child_charge) { create(:standard_charge, plan: child_plan, organization: charge.organization, billable_metric: charge.billable_metric, parent: charge) }
      let(:filter_value) { create(:charge_filter_value, charge_filter:, billable_metric_filter: card_location_filter, values: ["domestic"]) }

      before do
        filter_value
        create(:subscription, plan: child_plan, status: :active)
        child_charge
        allow(ChargeFilters::CascadeJob).to receive(:perform_later)
      end

      it "triggers filter-level cascade via ChargeFilters::CascadeJob" do
        service

        expect(ChargeFilters::CascadeJob).to have_received(:perform_later).with(
          charge.id,
          "destroy",
          hash_including("card_location"),
          nil,
          nil,
          nil
        )
      end
    end

    context "without cascade_updates when charge has children" do
      let(:child_plan) { create(:plan, organization: charge.organization, parent: charge.plan) }
      let(:child_charge) { create(:standard_charge, plan: child_plan, organization: charge.organization, billable_metric: charge.billable_metric, parent: charge) }
      let(:filter_value) { create(:charge_filter_value, charge_filter:, billable_metric_filter: card_location_filter, values: ["domestic"]) }

      before do
        filter_value
        create(:subscription, plan: child_plan, status: :active)
        child_charge
        allow(Charges::UpdateChildrenJob).to receive(:perform_later)
      end

      it "does not trigger cascade update" do
        service

        expect(Charges::UpdateChildrenJob).not_to have_received(:perform_later)
      end
    end
  end
end
