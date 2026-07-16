# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Plans::FixedChargesController do
  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:add_on) { create(:add_on, organization:) }

  describe "GET /api/v1/plans/:plan_code/fixed_charges" do
    subject { get_with_token(organization, "/api/v1/plans/#{plan.code}/fixed_charges") }

    let(:fixed_charge) { create(:fixed_charge, plan:, organization:, add_on:) }

    before { fixed_charge }

    it "returns a list of fixed charges" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:fixed_charges]).to be_present
      expect(json[:fixed_charges].length).to eq(1)
      expect(json[:fixed_charges].first[:lago_id]).to eq(fixed_charge.id)
      expect(json[:fixed_charges].first[:code]).to eq(fixed_charge.code)
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
      subject { get_with_token(organization, "/api/v1/plans/invalid_code/fixed_charges") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("plan")
      end
    end

    context "when plan has child fixed charges (overrides)" do
      let(:child_plan) { create(:plan, organization:, parent: plan) }
      let(:child_fixed_charge) { create(:fixed_charge, plan: child_plan, organization:, add_on:, parent: fixed_charge) }

      before { child_fixed_charge }

      it "only returns parent fixed charges" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:fixed_charges].length).to eq(1)
        expect(json[:fixed_charges].first[:lago_id]).to eq(fixed_charge.id)
      end
    end

    context "with pagination" do
      let(:fixed_charges) { create_list(:fixed_charge, 3, plan:, organization:, add_on:) }

      before do
        fixed_charge.destroy
        fixed_charges
      end

      it "returns paginated results" do
        get_with_token(organization, "/api/v1/plans/#{plan.code}/fixed_charges?per_page=2&page=1")

        expect(response).to have_http_status(:success)
        expect(json[:fixed_charges].length).to eq(2)
        expect(json[:meta][:current_page]).to eq(1)
        expect(json[:meta][:total_pages]).to eq(2)
      end
    end
  end

  describe "GET /api/v1/plans/:plan_code/fixed_charges/:code" do
    subject { get_with_token(organization, "/api/v1/plans/#{plan.code}/fixed_charges/#{fixed_charge.code}") }

    let(:fixed_charge) { create(:fixed_charge, plan:, organization:, add_on:) }

    it "returns the fixed charge" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:fixed_charge][:lago_id]).to eq(fixed_charge.id)
      expect(json[:fixed_charge][:code]).to eq(fixed_charge.code)
      expect(json[:fixed_charge][:charge_model]).to eq("standard")
      expect(json[:fixed_charge][:lago_add_on_id]).to eq(add_on.id)
    end

    context "when plan does not exist" do
      subject { get_with_token(organization, "/api/v1/plans/invalid_code/fixed_charges/#{fixed_charge.code}") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("plan")
      end
    end

    context "when fixed charge does not exist" do
      subject { get_with_token(organization, "/api/v1/plans/#{plan.code}/fixed_charges/invalid_code") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("fixed_charge")
      end
    end
  end

  describe "POST /api/v1/plans/:plan_code/fixed_charges" do
    subject { post_with_token(organization, "/api/v1/plans/#{plan.code}/fixed_charges", {fixed_charge: create_params}) }

    let(:create_params) do
      {
        add_on_id: add_on.id,
        code: "new_fixed_charge_code",
        charge_model: "standard",
        invoice_display_name: "Test Fixed Charge",
        units: 10,
        properties: {amount: "100"}
      }
    end

    it "creates a new fixed charge" do
      expect { subject }.to change { plan.fixed_charges.count }.by(1)

      expect(response).to have_http_status(:success)
      expect(json[:fixed_charge][:code]).to eq("new_fixed_charge_code")
      expect(json[:fixed_charge][:charge_model]).to eq("standard")
      expect(json[:fixed_charge][:invoice_display_name]).to eq("Test Fixed Charge")
      expect(json[:fixed_charge][:lago_add_on_id]).to eq(add_on.id)
      expect(json[:fixed_charge][:units]).to eq("10.0")
    end

    context "when using add_on_code instead of add_on_id" do
      let(:create_params) do
        {
          add_on_code: add_on.code,
          code: "new_fixed_charge_code",
          charge_model: "standard",
          units: 5,
          properties: {amount: "50"}
        }
      end

      it "creates a new fixed charge" do
        expect { subject }.to change { plan.fixed_charges.count }.by(1)

        expect(response).to have_http_status(:success)
        expect(json[:fixed_charge][:lago_add_on_id]).to eq(add_on.id)
      end
    end

    context "when plan does not exist" do
      subject { post_with_token(organization, "/api/v1/plans/invalid_code/fixed_charges", {fixed_charge: create_params}) }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("plan")
      end
    end

    context "when add_on does not exist" do
      let(:create_params) do
        {
          add_on_id: "invalid_id",
          code: "new_fixed_charge_code",
          charge_model: "standard"
        }
      end

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("add_on")
      end
    end

    context "with taxes" do
      let(:tax) { create(:tax, organization:) }
      let(:create_params) do
        {
          add_on_id: add_on.id,
          code: "taxed_fixed_charge",
          charge_model: "standard",
          units: 1,
          properties: {amount: "100"},
          tax_codes: [tax.code]
        }
      end

      it "creates a fixed charge with taxes" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:fixed_charge][:taxes]).to be_present
        expect(json[:fixed_charge][:taxes].length).to eq(1)
        expect(json[:fixed_charge][:taxes].first[:code]).to eq(tax.code)
      end
    end

    context "with cascade_updates" do
      subject { post_with_token(organization, "/api/v1/plans/#{plan.code}/fixed_charges", {fixed_charge: create_params.merge(cascade_updates: true)}) }

      let(:child_plan) { create(:plan, organization:, parent: plan) }

      before do
        create(:subscription, plan: child_plan, status: :active)
        allow(FixedCharges::CreateChildrenJob).to receive(:perform_later)
      end

      it "triggers cascade creation to children" do
        subject

        expect(response).to have_http_status(:success)
        expect(FixedCharges::CreateChildrenJob).to have_received(:perform_later)
      end
    end
  end

  describe "PUT /api/v1/plans/:plan_code/fixed_charges/:code" do
    subject { put_with_token(organization, "/api/v1/plans/#{plan.code}/fixed_charges/#{fixed_charge.code}", {fixed_charge: update_params}) }

    let(:fixed_charge) { create(:fixed_charge, plan:, organization:, add_on:) }
    let(:update_params) do
      {
        invoice_display_name: "Updated Fixed Charge Name",
        charge_model: "standard",
        units: 20,
        properties: {amount: "200"}
      }
    end

    it "updates the fixed charge" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:fixed_charge][:invoice_display_name]).to eq("Updated Fixed Charge Name")
      expect(json[:fixed_charge][:units]).to eq("20.0")
      expect(json[:fixed_charge][:properties][:amount]).to eq("200")
    end

    context "when plan does not exist" do
      subject { put_with_token(organization, "/api/v1/plans/invalid_code/fixed_charges/#{fixed_charge.code}", {fixed_charge: update_params}) }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("plan")
      end
    end

    context "when fixed charge does not exist" do
      subject { put_with_token(organization, "/api/v1/plans/#{plan.code}/fixed_charges/invalid_code", {fixed_charge: update_params}) }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("fixed_charge")
      end
    end

    context "when plan is attached to subscriptions" do
      let(:subscription) { create(:subscription, plan:) }

      before { subscription }

      it "updates only allowed fields" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:fixed_charge][:invoice_display_name]).to eq("Updated Fixed Charge Name")
      end
    end

    context "with cascade_updates" do
      subject { put_with_token(organization, "/api/v1/plans/#{plan.code}/fixed_charges/#{fixed_charge.code}", {fixed_charge: update_params.merge(cascade_updates: true)}) }

      let(:child_plan) { create(:plan, organization:, parent: plan) }
      let(:child_fixed_charge) { create(:fixed_charge, plan: child_plan, organization:, add_on:, parent: fixed_charge) }

      before do
        create(:subscription, plan: child_plan, status: :active)
        child_fixed_charge
        allow(FixedCharges::UpdateChildrenJob).to receive(:perform_later)
      end

      it "passes cascade_updates to the service" do
        subject

        expect(response).to have_http_status(:success)
        expect(FixedCharges::UpdateChildrenJob).to have_received(:perform_later)
      end
    end
  end

  describe "DELETE /api/v1/plans/:plan_code/fixed_charges/:code" do
    subject { delete_with_token(organization, "/api/v1/plans/#{plan.code}/fixed_charges/#{fixed_charge.code}") }

    let(:fixed_charge) { create(:fixed_charge, plan:, organization:, add_on:) }

    it "soft deletes the fixed charge" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:fixed_charge][:lago_id]).to eq(fixed_charge.id)
      expect(fixed_charge.reload.deleted_at).to be_present
    end

    context "when plan does not exist" do
      subject { delete_with_token(organization, "/api/v1/plans/invalid_code/fixed_charges/#{fixed_charge.code}") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("plan")
      end
    end

    context "when fixed charge does not exist" do
      subject { delete_with_token(organization, "/api/v1/plans/#{plan.code}/fixed_charges/invalid_code") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("fixed_charge")
      end
    end

    context "with cascade_updates" do
      subject { delete_with_token(organization, "/api/v1/plans/#{plan.code}/fixed_charges/#{fixed_charge.code}", {fixed_charge: {cascade_updates: true}}) }

      let(:child_plan) { create(:plan, organization:, parent: plan) }
      let(:child_fixed_charge) { create(:fixed_charge, plan: child_plan, organization:, add_on:, parent: fixed_charge) }

      before do
        child_fixed_charge
        allow(FixedCharges::DestroyChildrenJob).to receive(:perform_later)
      end

      it "cascades the deletion to children" do
        subject

        expect(response).to have_http_status(:success)
        expect(FixedCharges::DestroyChildrenJob).to have_received(:perform_later).with(fixed_charge.id)
      end
    end
  end
end
