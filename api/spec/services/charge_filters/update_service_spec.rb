# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeFilters::UpdateService do
  subject(:service) { described_class.call(charge_filter:, params:) }

  let(:charge) { create(:standard_charge) }
  let(:charge_filter) { create(:charge_filter, charge:, invoice_display_name: "Original Name", properties: {"amount" => "10"}) }
  let(:params) { {} }

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
      subject(:service) { described_class.call(charge_filter: nil, params: {}) }

      it "returns not found failure" do
        expect(service).not_to be_success
        expect(service.error).to be_a(BaseService::NotFoundFailure)
        expect(service.error.resource).to eq("charge_filter")
      end
    end

    context "when updating invoice_display_name and properties" do
      let(:params) do
        {
          invoice_display_name: "New Display Name",
          properties: {amount: "200"}
        }
      end

      before do
        create(:charge_filter_value, charge_filter:, billable_metric_filter: card_location_filter, values: ["domestic"])
      end

      it "updates both attributes" do
        expect(service).to be_success
        expect(charge_filter.reload).to have_attributes(
          invoice_display_name: "New Display Name",
          properties: {"amount" => "200"}
        )
      end
    end

    context "with presentation_group_keys in properties" do
      let(:params) do
        {
          properties: {amount: "200", presentation_group_keys: [{value: "region"}]}
        }
      end

      it "ignores presentation_group_keys" do
        expect(service).to be_success
        expect(charge_filter.reload.properties).to eq({"amount" => "200"})
        expect(charge_filter.reload.properties).not_to have_key("presentation_group_keys")
      end
    end

    context "with graduated charge model" do
      let(:charge) { create(:graduated_charge) }
      let(:charge_filter) { create(:charge_filter, charge:, properties: {"graduated_ranges" => [{"from_value" => 0, "to_value" => nil, "per_unit_amount" => "0", "flat_amount" => "100"}]}) }
      let(:params) do
        {
          properties: {
            amount: "10",
            graduated_ranges: [{from_value: 0, to_value: nil, per_unit_amount: "0", flat_amount: "200"}]
          }
        }
      end

      it "filters properties based on charge model" do
        expect(service).to be_success
        expect(charge_filter.reload.properties).to eq(
          "graduated_ranges" => [
            {"from_value" => 0, "to_value" => nil, "per_unit_amount" => "0", "flat_amount" => "200"}
          ]
        )
      end
    end

    context "with cascade_updates" do
      subject(:service) { described_class.call(charge_filter:, params:, cascade_updates: true) }

      let(:child_plan) { create(:plan, organization: charge.organization, parent: charge.plan) }
      let(:child_charge) { create(:standard_charge, plan: child_plan, organization: charge.organization, billable_metric: charge.billable_metric, parent: charge) }
      let(:params) { {properties: {amount: "150"}} }

      before do
        create(:charge_filter_value, charge_filter:, billable_metric_filter: card_location_filter, values: ["domestic"])
        create(:subscription, plan: child_plan, status: :active)
        child_charge
        allow(ChargeFilters::CascadeJob).to receive(:perform_later)
      end

      it "triggers filter-level cascade via ChargeFilters::CascadeJob" do
        service

        expect(ChargeFilters::CascadeJob).to have_received(:perform_later).with(
          charge.id,
          "update",
          hash_including("card_location"),
          hash_including("amount"),
          hash_including("amount"),
          anything
        )
      end
    end

    context "without cascade_updates when charge has children" do
      let(:child_plan) { create(:plan, organization: charge.organization, parent: charge.plan) }
      let(:child_charge) { create(:standard_charge, plan: child_plan, organization: charge.organization, billable_metric: charge.billable_metric, parent: charge) }
      let(:params) { {properties: {amount: "150"}} }

      before do
        create(:charge_filter_value, charge_filter:, billable_metric_filter: card_location_filter, values: ["domestic"])
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
