# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Plans::ChargesController do
  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }

  describe "GET /api/v1/plans/:plan_code/charges" do
    subject { get_with_token(organization, "/api/v1/plans/#{plan.code}/charges") }

    let(:charge) { create(:standard_charge, plan:, organization:, billable_metric:) }

    before { charge }

    it "returns a list of charges" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:charges]).to be_present
      expect(json[:charges].length).to eq(1)
      expect(json[:charges].first[:lago_id]).to eq(charge.id)
      expect(json[:charges].first[:code]).to eq(charge.code)
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
      subject { get_with_token(organization, "/api/v1/plans/invalid_code/charges") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("plan")
      end
    end

    context "when plan has child charges (overrides)" do
      let(:child_plan) { create(:plan, organization:, parent: plan) }
      let(:child_charge) { create(:standard_charge, plan: child_plan, organization:, billable_metric:, parent: charge) }

      before { child_charge }

      it "only returns parent charges" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:charges].length).to eq(1)
        expect(json[:charges].first[:lago_id]).to eq(charge.id)
      end
    end

    context "with pagination" do
      let(:charges) { create_list(:standard_charge, 3, plan:, organization:, billable_metric:) }

      before do
        charge.destroy
        charges
      end

      it "returns paginated results" do
        get_with_token(organization, "/api/v1/plans/#{plan.code}/charges?per_page=2&page=1")

        expect(response).to have_http_status(:success)
        expect(json[:charges].length).to eq(2)
        expect(json[:meta][:current_page]).to eq(1)
        expect(json[:meta][:total_pages]).to eq(2)
      end
    end
  end

  describe "GET /api/v1/plans/:plan_code/charges/:code" do
    subject { get_with_token(organization, "/api/v1/plans/#{plan.code}/charges/#{charge.code}") }

    let(:charge) { create(:standard_charge, plan:, organization:, billable_metric:) }

    it "returns the charge" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:charge][:lago_id]).to eq(charge.id)
      expect(json[:charge][:code]).to eq(charge.code)
      expect(json[:charge][:charge_model]).to eq("standard")
      expect(json[:charge][:lago_billable_metric_id]).to eq(billable_metric.id)
    end

    context "when plan does not exist" do
      subject { get_with_token(organization, "/api/v1/plans/invalid_code/charges/#{charge.code}") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("plan")
      end
    end

    context "when charge does not exist" do
      subject { get_with_token(organization, "/api/v1/plans/#{plan.code}/charges/invalid_code") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("charge")
      end
    end
  end

  describe "POST /api/v1/plans/:plan_code/charges" do
    subject { post_with_token(organization, "/api/v1/plans/#{plan.code}/charges", {charge: create_params}) }

    let(:create_params) do
      {
        billable_metric_id: billable_metric.id,
        code: "new_charge_code",
        charge_model: "standard",
        invoice_display_name: "Test Charge",
        properties: {amount: "100"}
      }
    end

    it "creates a new charge" do
      expect { subject }.to change { plan.charges.count }.by(1)

      expect(response).to have_http_status(:success)
      expect(json[:charge][:code]).to eq("new_charge_code")
      expect(json[:charge][:charge_model]).to eq("standard")
      expect(json[:charge][:invoice_display_name]).to eq("Test Charge")
      expect(json[:charge][:lago_billable_metric_id]).to eq(billable_metric.id)
    end

    context "when plan does not exist" do
      subject { post_with_token(organization, "/api/v1/plans/invalid_code/charges", {charge: create_params}) }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("plan")
      end
    end

    context "when billable_metric does not exist" do
      let(:create_params) do
        {
          billable_metric_id: "invalid_id",
          code: "new_charge_code",
          charge_model: "standard"
        }
      end

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("billable_metric")
      end
    end

    context "with filters" do
      let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric:) }
      let(:create_params) do
        {
          billable_metric_id: billable_metric.id,
          code: "filtered_charge",
          charge_model: "standard",
          properties: {amount: "100"},
          filters: [
            {
              invoice_display_name: "Filter 1",
              properties: {amount: "50"},
              values: {billable_metric_filter.key => [billable_metric_filter.values.first]}
            }
          ]
        }
      end

      it "creates a charge with filters" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:charge][:filters].length).to eq(1)
        expect(json[:charge][:filters].first[:invoice_display_name]).to eq("Filter 1")
        expect(json[:charge][:filters].first[:properties]).to include(amount: "50")
      end

      context "when filter properties include presentation_group_keys" do
        let(:create_params) do
          {
            billable_metric_id: billable_metric.id,
            code: "filtered_charge",
            charge_model: "standard",
            properties: {amount: "100"},
            filters: [
              {
                invoice_display_name: "Filter 1",
                properties: {
                  amount: "50",
                  presentation_group_keys: [
                    {value: "region", options: {display_in_invoice: true}}
                  ]
                },
                values: {billable_metric_filter.key => [billable_metric_filter.values.first]}
              }
            ]
          }
        end

        it "ignores charge filter presentation_group_keys" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:charge][:filters].first[:properties]).not_to have_key(:presentation_group_keys)
        end
      end
    end

    context "with taxes" do
      let(:tax) { create(:tax, organization:) }
      let(:create_params) do
        {
          billable_metric_id: billable_metric.id,
          code: "taxed_charge",
          charge_model: "standard",
          properties: {amount: "100"},
          tax_codes: [tax.code]
        }
      end

      it "creates a charge with taxes" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:charge][:taxes]).to be_present
        expect(json[:charge][:taxes].length).to eq(1)
        expect(json[:charge][:taxes].first[:code]).to eq(tax.code)
      end
    end

    context "with applied_pricing_unit", :premium do
      let(:pricing_unit) { create(:pricing_unit, organization:) }
      let(:create_params) do
        {
          billable_metric_id: billable_metric.id,
          code: "priced_charge",
          charge_model: "standard",
          properties: {amount: "100"},
          applied_pricing_unit: {code: pricing_unit.code, conversion_rate: "2.5"}
        }
      end

      it "creates a charge with applied pricing unit" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:charge][:applied_pricing_unit]).to be_present
        expect(json[:charge][:applied_pricing_unit][:code]).to eq(pricing_unit.code)
        expect(json[:charge][:applied_pricing_unit][:conversion_rate]).to eq("2.5")
      end
    end

    context "with cascade_updates" do
      subject { post_with_token(organization, "/api/v1/plans/#{plan.code}/charges", {charge: create_params.merge(cascade_updates: true)}) }

      let(:child_plan) { create(:plan, organization:, parent: plan) }

      before do
        create(:subscription, plan: child_plan, status: :active)
        allow(Charges::CreateChildrenJob).to receive(:perform_later)
      end

      it "triggers cascade creation to children" do
        subject

        expect(response).to have_http_status(:success)
        expect(Charges::CreateChildrenJob).to have_received(:perform_later)
      end
    end

    context "with accepts_target_wallet" do
      let(:create_params) do
        {
          billable_metric_id: billable_metric.id,
          code: "wallet_target_charge",
          charge_model: "standard",
          properties: {amount: "100"},
          accepts_target_wallet: true
        }
      end

      context "when license is not premium" do
        it "ignores accepts_target_wallet" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:charge][:accepts_target_wallet]).to be false
        end
      end

      context "when license is premium", :premium do
        context "when events_targeting_wallets is not enabled" do
          it "does not set accepts_target_wallet" do
            subject

            expect(response).to have_http_status(:success)
            expect(json[:charge][:accepts_target_wallet]).to be false
          end
        end

        context "when events_targeting_wallets is enabled" do
          before do
            organization.update!(premium_integrations: ["events_targeting_wallets"])
          end

          it "sets accepts_target_wallet" do
            subject

            expect(response).to have_http_status(:success)
            expect(json[:charge][:accepts_target_wallet]).to be true
          end
        end
      end
    end

    context "with presentation_group_keys" do
      context "when presentation_group_keys is an empty array" do
        let(:create_params) do
          {
            billable_metric_id: billable_metric.id,
            code: "new_charge_code",
            charge_model: "standard",
            properties: {amount: "100", presentation_group_keys: []}
          }
        end

        it "creates a charge without storing presentation_group_keys" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:charge][:properties][:presentation_group_keys]).to be_nil
        end
      end

      context "when presentation_group_keys contains only value" do
        let(:create_params) do
          {
            billable_metric_id: billable_metric.id,
            code: "new_charge_code",
            charge_model: "standard",
            properties: {amount: "100", presentation_group_keys: [{value: "region"}]}
          }
        end

        it "creates a charge with presentation_group_keys" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:charge][:properties][:presentation_group_keys]).to eq([{value: "region"}])
        end
      end

      context "when presentation_group_keys contains both value and options" do
        let(:create_params) do
          {
            billable_metric_id: billable_metric.id,
            code: "new_charge_code",
            charge_model: "standard",
            properties: {
              amount: "100",
              presentation_group_keys: [
                {value: "region", options: {display_in_invoice: true}},
                {value: "country"}
              ]
            }
          }
        end

        it "creates a charge with presentation_group_keys including options" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:charge][:properties][:presentation_group_keys]).to eq([
            {value: "region", options: {display_in_invoice: true}},
            {value: "country"}
          ])
        end
      end
    end
  end

  describe "PUT /api/v1/plans/:plan_code/charges/:code" do
    subject { put_with_token(organization, "/api/v1/plans/#{plan.code}/charges/#{charge.code}", {charge: update_params}) }

    let(:charge) { create(:standard_charge, plan:, organization:, billable_metric:) }
    let(:update_params) do
      {
        invoice_display_name: "Updated Charge Name",
        charge_model: "standard",
        properties: {amount: "200"}
      }
    end

    it "updates the charge" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:charge][:invoice_display_name]).to eq("Updated Charge Name")
      expect(json[:charge][:properties][:amount]).to eq("200")
    end

    context "when plan does not exist" do
      subject { put_with_token(organization, "/api/v1/plans/invalid_code/charges/#{charge.code}", {charge: update_params}) }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("plan")
      end
    end

    context "when charge does not exist" do
      subject { put_with_token(organization, "/api/v1/plans/#{plan.code}/charges/invalid_code", {charge: update_params}) }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("charge")
      end
    end

    context "when plan is attached to subscriptions" do
      let(:subscription) { create(:subscription, plan:) }

      before { subscription }

      it "updates only allowed fields" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:charge][:invoice_display_name]).to eq("Updated Charge Name")
      end
    end

    context "with cascade_updates" do
      subject { put_with_token(organization, "/api/v1/plans/#{plan.code}/charges/#{charge.code}", {charge: update_params.merge(cascade_updates: true)}) }

      let(:child_plan) { create(:plan, organization:, parent: plan) }
      let(:child_charge) { create(:standard_charge, plan: child_plan, organization:, billable_metric:, parent: charge) }

      before do
        create(:subscription, plan: child_plan, status: :active)
        child_charge
        allow(Charges::UpdateChildrenJob).to receive(:perform_later)
      end

      it "passes cascade_updates to the service" do
        subject

        expect(response).to have_http_status(:success)
        expect(Charges::UpdateChildrenJob).to have_received(:perform_later)
      end
    end

    context "with accepts_target_wallet" do
      let(:update_params) do
        {
          charge_model: "standard",
          properties: {amount: "200"},
          accepts_target_wallet: true
        }
      end

      context "when license is not premium" do
        it "ignores accepts_target_wallet" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:charge][:accepts_target_wallet]).to be false
        end
      end

      context "when license is premium", :premium do
        context "when events_targeting_wallets is not enabled" do
          it "does not set accepts_target_wallet" do
            subject

            expect(response).to have_http_status(:success)
            expect(json[:charge][:accepts_target_wallet]).to be false
          end
        end

        context "when events_targeting_wallets is enabled" do
          before do
            organization.update!(premium_integrations: ["events_targeting_wallets"])
          end

          it "sets accepts_target_wallet" do
            subject

            expect(response).to have_http_status(:success)
            expect(json[:charge][:accepts_target_wallet]).to be true
          end
        end
      end
    end

    context "with presentation_group_keys" do
      context "when presentation_group_keys contains only value" do
        let(:update_params) do
          {
            charge_model: "standard",
            properties: {amount: "200", presentation_group_keys: [{value: "region"}]}
          }
        end

        it "updates the charge with presentation_group_keys" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:charge][:properties][:presentation_group_keys]).to eq([{value: "region"}])
        end
      end

      context "when presentation_group_keys contains both value and options" do
        let(:update_params) do
          {
            charge_model: "standard",
            properties: {
              amount: "200",
              presentation_group_keys: [
                {value: "region", options: {display_in_invoice: true}},
                {value: "country"}
              ]
            }
          }
        end

        it "updates the charge with presentation_group_keys including options" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:charge][:properties][:presentation_group_keys]).to eq([
            {value: "region", options: {display_in_invoice: true}},
            {value: "country"}
          ])
        end
      end

      context "when removing existing presentation_group_keys" do
        let(:charge) do
          create(:standard_charge, plan:, organization:, billable_metric:,
            properties: {"amount" => "100", "presentation_group_keys" => [{"value" => "region"}]})
        end
        let(:update_params) do
          {
            charge_model: "standard",
            properties: {amount: "200", presentation_group_keys: []}
          }
        end

        it "removes presentation_group_keys from the charge" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:charge][:properties][:presentation_group_keys]).to be_nil
        end
      end
    end
  end

  describe "DELETE /api/v1/plans/:plan_code/charges/:code" do
    subject { delete_with_token(organization, "/api/v1/plans/#{plan.code}/charges/#{charge.code}") }

    let(:charge) { create(:standard_charge, plan:, organization:, billable_metric:) }

    it "soft deletes the charge" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:charge][:lago_id]).to eq(charge.id)
      expect(charge.reload.deleted_at).to be_present
    end

    context "when plan does not exist" do
      subject { delete_with_token(organization, "/api/v1/plans/invalid_code/charges/#{charge.code}") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("plan")
      end
    end

    context "when charge does not exist" do
      subject { delete_with_token(organization, "/api/v1/plans/#{plan.code}/charges/invalid_code") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("charge")
      end
    end

    context "with cascade_updates" do
      subject { delete_with_token(organization, "/api/v1/plans/#{plan.code}/charges/#{charge.code}", {charge: {cascade_updates: true}}) }

      let(:child_plan) { create(:plan, organization:, parent: plan) }
      let(:child_charge) { create(:standard_charge, plan: child_plan, organization:, billable_metric:, parent: charge) }

      before do
        child_charge
        allow(Charges::DestroyChildrenJob).to receive(:perform_later)
      end

      it "cascades the deletion to children" do
        subject

        expect(response).to have_http_status(:success)
        expect(Charges::DestroyChildrenJob).to have_received(:perform_later).with(charge.id)
      end
    end
  end
end
