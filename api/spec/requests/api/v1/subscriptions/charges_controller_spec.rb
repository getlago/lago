# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Subscriptions::ChargesController do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:external_id) { "sub_123" }
  let(:external_id_query_param) { external_id }
  let(:subscription) { create(:subscription, customer:, plan:, external_id:) }
  let(:charge) { create(:standard_charge, plan:, organization:, billable_metric:) }

  before do
    subscription
    charge
  end

  describe "GET /api/v1/subscriptions/:external_id/charges" do
    subject { get_with_token(organization, "/api/v1/subscriptions/#{external_id_query_param}/charges") }

    it_behaves_like "requires API permission", "subscription", "read"

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

    context "when subscription does not exist" do
      let(:external_id_query_param) { "invalid_external_id" }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("subscription")
      end
    end

    context "when subscription has plan override with charges" do
      let(:overridden_plan) { create(:plan, organization:, parent: plan) }
      let(:subscription) { create(:subscription, customer:, plan: overridden_plan, external_id:) }
      let(:overridden_charge) { create(:standard_charge, plan: overridden_plan, organization:, billable_metric:, parent: charge) }

      before { overridden_charge }

      it "returns overridden charges" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:charges].length).to eq(1)
        expect(json[:charges].first[:lago_id]).to eq(overridden_charge.id)
        expect(json[:charges].first[:lago_parent_id]).to eq(charge.id)
      end
    end

    context "with pagination" do
      let(:charges) { create_list(:standard_charge, 3, plan:, organization:, billable_metric:) }

      before do
        charge.discard
        charges
      end

      it "returns paginated results" do
        get_with_token(organization, "/api/v1/subscriptions/#{external_id_query_param}/charges?per_page=2&page=1")

        expect(response).to have_http_status(:success)
        expect(json[:charges].length).to eq(2)
        expect(json[:meta][:current_page]).to eq(1)
        expect(json[:meta][:total_pages]).to eq(2)
      end
    end

    context "when charges have applied taxes" do
      let(:tax) { create(:tax, organization:) }

      before { create(:charge_applied_tax, charge:, tax:) }

      it "includes taxes in the response" do
        subject

        expect(json[:charges].first[:taxes]).to be_an(Array)
        expect(json[:charges].first[:taxes]).not_to be_empty
        expect(json[:charges].first[:taxes].first[:code]).to eq(tax.code)
      end
    end
  end

  describe "GET /api/v1/subscriptions/:external_id/charges/:code" do
    subject { get_with_token(organization, "/api/v1/subscriptions/#{external_id_query_param}/charges/#{charge.code}") }

    it_behaves_like "requires API permission", "subscription", "read"

    it "returns the charge" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:charge][:lago_id]).to eq(charge.id)
      expect(json[:charge][:code]).to eq(charge.code)
      expect(json[:charge][:charge_model]).to eq("standard")
      expect(json[:charge][:lago_billable_metric_id]).to eq(billable_metric.id)
    end

    context "when subscription does not exist" do
      let(:external_id_query_param) { "invalid_external_id" }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("subscription")
      end
    end

    context "when charge does not exist" do
      subject { get_with_token(organization, "/api/v1/subscriptions/#{external_id_query_param}/charges/invalid_code") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("charge")
      end
    end

    context "when subscription has plan override with charge override" do
      let(:overridden_plan) { create(:plan, organization:, parent: plan) }
      let(:subscription) { create(:subscription, customer:, plan: overridden_plan, external_id:) }
      let(:overridden_charge) { create(:standard_charge, plan: overridden_plan, organization:, billable_metric:, parent: charge, code: charge.code) }

      before { overridden_charge }

      it "returns the overridden charge" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:charge][:lago_id]).to eq(overridden_charge.id)
        expect(json[:charge][:lago_parent_id]).to eq(charge.id)
      end
    end
  end

  describe "PUT /api/v1/subscriptions/:external_id/charges/:code" do
    subject { put_with_token(organization, "/api/v1/subscriptions/#{external_id_query_param}/charges/#{charge.code}", {charge: update_params}) }

    let(:update_params) do
      {
        invoice_display_name: "Updated Charge Name",
        min_amount_cents: 500,
        properties: {amount: "200"}
      }
    end

    context "with premium license", :premium do
      it_behaves_like "requires API permission", "subscription", "write"

      it "creates a plan override and charge override" do
        expect { subject }.to change(Plan, :count).by(1).and change(Charge, :count).by(1)

        expect(response).to have_http_status(:success)
        expect(json[:charge][:invoice_display_name]).to eq("Updated Charge Name")
        expect(json[:charge][:min_amount_cents]).to eq(500)
        expect(json[:charge][:properties][:amount]).to eq("200")
        expect(json[:charge][:lago_parent_id]).to eq(charge.id)
      end

      it "updates the subscription to use the overridden plan" do
        subject

        subscription.reload
        expect(subscription.plan.parent_id).to eq(plan.id)
      end

      context "when subscription does not exist" do
        let(:external_id_query_param) { "invalid_external_id" }

        it "returns not found error" do
          subject

          expect(response).to be_not_found_error("subscription")
        end
      end

      context "when charge does not exist" do
        subject { put_with_token(organization, "/api/v1/subscriptions/#{external_id_query_param}/charges/invalid_code", {charge: update_params}) }

        it "returns not found error" do
          subject

          expect(response).to be_not_found_error("charge")
        end
      end

      context "when subscription already has plan override" do
        let(:overridden_plan) { create(:plan, organization:, parent: plan) }
        let(:subscription) { create(:subscription, customer:, plan: overridden_plan, external_id:) }
        let(:overridden_charge) { create(:standard_charge, plan: overridden_plan, organization:, billable_metric:, parent: charge, code: charge.code) }

        before { overridden_charge }

        it "does not create a new plan" do
          expect { subject }.not_to change(Plan, :count)
        end

        it "updates the existing charge override" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:charge][:lago_id]).to eq(overridden_charge.id)
          expect(json[:charge][:invoice_display_name]).to eq("Updated Charge Name")
          expect(json[:charge][:min_amount_cents]).to eq(500)
        end
      end

      context "with taxes" do
        let(:tax) { create(:tax, organization:) }
        let(:update_params) do
          {
            invoice_display_name: "Taxed Charge",
            tax_codes: [tax.code]
          }
        end

        it "creates a charge override with taxes" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:charge][:taxes]).to be_present
          expect(json[:charge][:taxes].length).to eq(1)
          expect(json[:charge][:taxes].first[:code]).to eq(tax.code)
        end
      end
    end

    context "without premium license" do
      it "returns forbidden error" do
        subject

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
