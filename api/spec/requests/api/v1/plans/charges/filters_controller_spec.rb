# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Plans::Charges::FiltersController do
  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:charge) { create(:standard_charge, plan:, organization:, billable_metric:) }
  let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric:, key: "region", values: %w[us eu]) }

  describe "GET /api/v1/plans/:plan_code/charges/:charge_code/filters" do
    subject { get_with_token(organization, "/api/v1/plans/#{plan.code}/charges/#{charge.code}/filters") }

    let(:charge_filter) { create(:charge_filter, charge:) }

    before do
      create(:charge_filter_value, charge_filter:, billable_metric_filter:, values: ["us"])
    end

    it "returns a list of charge filters" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:filters]).to be_present
      expect(json[:filters].length).to eq(1)
      expect(json[:filters].first[:lago_id]).to eq(charge_filter.id)
    end

    it "returns pagination metadata" do
      subject

      expect(json[:meta]).to include(
        current_page: 1,
        next_page: nil,
        prev_page: nil,
        total_pages: 1,
        total_count: 1
      )
    end

    context "when plan does not exist" do
      subject { get_with_token(organization, "/api/v1/plans/invalid_code/charges/#{charge.code}/filters") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("plan")
      end
    end

    context "when charge does not exist" do
      subject { get_with_token(organization, "/api/v1/plans/#{plan.code}/charges/invalid_code/filters") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("charge")
      end
    end
  end

  describe "GET /api/v1/plans/:plan_code/charges/:charge_code/filters/:id" do
    subject { get_with_token(organization, "/api/v1/plans/#{plan.code}/charges/#{charge.code}/filters/#{charge_filter.id}") }

    let(:charge_filter) { create(:charge_filter, charge:, invoice_display_name: "US Region") }

    before do
      create(:charge_filter_value, charge_filter:, billable_metric_filter:, values: ["us"])
    end

    it "returns the charge filter" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:filter][:lago_id]).to eq(charge_filter.id)
      expect(json[:filter][:invoice_display_name]).to eq("US Region")
      expect(json[:filter][:values]).to eq({region: ["us"]})
    end

    context "when plan does not exist" do
      subject { get_with_token(organization, "/api/v1/plans/invalid_code/charges/#{charge.code}/filters/#{charge_filter.id}") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("plan")
      end
    end

    context "when charge does not exist" do
      subject { get_with_token(organization, "/api/v1/plans/#{plan.code}/charges/invalid_code/filters/#{charge_filter.id}") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("charge")
      end
    end

    context "when charge filter does not exist" do
      subject { get_with_token(organization, "/api/v1/plans/#{plan.code}/charges/#{charge.code}/filters/#{SecureRandom.uuid}") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("charge_filter")
      end
    end
  end

  describe "POST /api/v1/plans/:plan_code/charges/:charge_code/filters" do
    subject { post_with_token(organization, "/api/v1/plans/#{plan.code}/charges/#{charge.code}/filters", {filter: create_params}) }

    let(:create_params) do
      {
        invoice_display_name: "US Region Filter",
        properties: {amount: "50"},
        values: {billable_metric_filter.key => ["us"]}
      }
    end

    it "creates a new charge filter" do
      expect { subject }.to change { charge.filters.count }.by(1)

      expect(response).to have_http_status(:success)
      expect(json[:filter][:invoice_display_name]).to eq("US Region Filter")
      expect(json[:filter][:properties]).to include(amount: "50")
      expect(json[:filter][:values]).to eq({region: ["us"]})
    end

    context "when plan does not exist" do
      subject { post_with_token(organization, "/api/v1/plans/invalid_code/charges/#{charge.code}/filters", {filter: create_params}) }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("plan")
      end
    end

    context "when charge does not exist" do
      subject { post_with_token(organization, "/api/v1/plans/#{plan.code}/charges/invalid_code/filters", {filter: create_params}) }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("charge")
      end
    end

    context "when values are missing" do
      let(:create_params) do
        {
          invoice_display_name: "US Region Filter",
          properties: {amount: "50"}
        }
      end

      it "returns validation error" do
        subject

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json[:error_details]).to include(:values)
      end
    end

    context "with cascade_updates" do
      subject do
        post_with_token(
          organization,
          "/api/v1/plans/#{plan.code}/charges/#{charge.code}/filters",
          {filter: create_params.merge(cascade_updates: true)}
        )
      end

      let(:child_plan) { create(:plan, organization:, parent: plan) }
      let(:child_charge) { create(:standard_charge, plan: child_plan, organization:, billable_metric:, parent: charge) }

      before do
        create(:subscription, plan: child_plan, status: :active)
        child_charge
        allow(ChargeFilters::CascadeJob).to receive(:perform_later)
      end

      it "triggers cascade to children" do
        subject

        expect(response).to have_http_status(:success)
        expect(ChargeFilters::CascadeJob).to have_received(:perform_later)
      end
    end

    context "with presentation_group_keys" do
      let(:create_params) do
        {
          invoice_display_name: "US Region Filter",
          properties: {amount: "50", presentation_group_keys: [{value: "region"}]},
          values: {billable_metric_filter.key => ["us"]}
        }
      end

      it "ignores presentation_group_keys" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:filter][:properties]).not_to have_key(:presentation_group_keys)
      end
    end
  end

  describe "PUT /api/v1/plans/:plan_code/charges/:charge_code/filters/:id" do
    subject { put_with_token(organization, "/api/v1/plans/#{plan.code}/charges/#{charge.code}/filters/#{charge_filter.id}", {filter: update_params}) }

    let(:charge_filter) { create(:charge_filter, charge:, invoice_display_name: "Original Name", properties: {"amount" => "10"}) }
    let(:update_params) do
      {
        invoice_display_name: "Updated Name",
        properties: {amount: "100"}
      }
    end

    before do
      create(:charge_filter_value, charge_filter:, billable_metric_filter:, values: ["us"])
    end

    it "updates the charge filter" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:filter][:invoice_display_name]).to eq("Updated Name")
      expect(json[:filter][:properties]).to include(amount: "100")
    end

    context "when plan does not exist" do
      subject { put_with_token(organization, "/api/v1/plans/invalid_code/charges/#{charge.code}/filters/#{charge_filter.id}", {filter: update_params}) }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("plan")
      end
    end

    context "when charge does not exist" do
      subject { put_with_token(organization, "/api/v1/plans/#{plan.code}/charges/invalid_code/filters/#{charge_filter.id}", {filter: update_params}) }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("charge")
      end
    end

    context "when charge filter does not exist" do
      subject { put_with_token(organization, "/api/v1/plans/#{plan.code}/charges/#{charge.code}/filters/#{SecureRandom.uuid}", {filter: update_params}) }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("charge_filter")
      end
    end

    context "with presentation_group_keys" do
      let(:update_params) do
        {
          properties: {amount: "100", presentation_group_keys: [{value: "region"}]}
        }
      end

      it "ignores presentation_group_keys" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:filter][:properties]).not_to have_key(:presentation_group_keys)
      end
    end
  end

  describe "DELETE /api/v1/plans/:plan_code/charges/:charge_code/filters/:id" do
    subject { delete_with_token(organization, "/api/v1/plans/#{plan.code}/charges/#{charge.code}/filters/#{charge_filter.id}") }

    let(:charge_filter) { create(:charge_filter, charge:) }
    let(:charge_filter_value) do
      create(:charge_filter_value, charge_filter:, billable_metric_filter:, values: ["us"])
    end

    before { charge_filter_value }

    it "soft deletes the charge filter" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:filter][:lago_id]).to eq(charge_filter.id)
      expect(charge_filter.reload.deleted_at).to be_present
    end

    it "soft deletes the charge filter values" do
      subject

      expect(charge_filter_value.reload.deleted_at).to be_present
    end

    context "when plan does not exist" do
      subject { delete_with_token(organization, "/api/v1/plans/invalid_code/charges/#{charge.code}/filters/#{charge_filter.id}") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("plan")
      end
    end

    context "when charge does not exist" do
      subject { delete_with_token(organization, "/api/v1/plans/#{plan.code}/charges/invalid_code/filters/#{charge_filter.id}") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("charge")
      end
    end

    context "when charge filter does not exist" do
      subject { delete_with_token(organization, "/api/v1/plans/#{plan.code}/charges/#{charge.code}/filters/#{SecureRandom.uuid}") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("charge_filter")
      end
    end
  end
end
