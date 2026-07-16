# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Subscriptions::FixedChargesController do
  let(:external_id) { "sub+1" }
  let(:external_id_query_param) { external_id }
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:add_on) { create(:add_on, organization:) }
  let(:subscription) { create(:subscription, external_id:, customer:, plan:) }
  let(:fixed_charge) { create(:fixed_charge, plan:, organization:, add_on:) }
  let(:deleted_fixed_charge) { create(:fixed_charge, :deleted, plan:, organization:) }

  before do
    subscription
    fixed_charge
    deleted_fixed_charge
  end

  describe "GET /api/v1/subscriptions/:external_id/fixed_charges" do
    subject { get_with_token(organization, "/api/v1/subscriptions/#{external_id_query_param}/fixed_charges") }

    it_behaves_like "requires API permission", "subscription", "read"

    context "when there are fixed charges" do
      it "retrieves the list of fixed charges" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:fixed_charges]).to be_present
        expect(json[:fixed_charges].first).to include({
          lago_id: fixed_charge.id,
          lago_add_on_id: fixed_charge.add_on_id,
          invoice_display_name: fixed_charge.invoice_display_name,
          add_on_code: fixed_charge.add_on.code,
          created_at: fixed_charge.created_at.iso8601,
          charge_model: fixed_charge.charge_model,
          pay_in_advance: fixed_charge.pay_in_advance,
          prorated: fixed_charge.prorated,
          properties: fixed_charge.properties.symbolize_keys,
          units: fixed_charge.units.to_s
        })
      end
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

    context "when there is only deleted fixed charges" do
      let(:fixed_charge) { nil }

      it do
        subject
        expect(json[:fixed_charges]).to be_empty
      end
    end

    context "when a per-subscription units override exists" do
      let(:fixed_charge) { create(:fixed_charge, plan:, organization:, add_on:, units: 10) }

      before do
        create(:subscription_fixed_charge_units_override, subscription:, fixed_charge:, organization:, units: 42)
      end

      it "returns the overridden units" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:fixed_charges].first[:units]).to eq("42.0")
      end
    end

    context "when fixed charges have applied taxes" do
      let(:fixed_charge) { create(:fixed_charge, :with_applied_taxes, plan:, organization:) }

      it "includes taxes in the response" do
        subject
        expect(json[:fixed_charges].first).to include(:taxes)
        expect(json[:fixed_charges].first[:taxes]).to be_an(Array)
        expect(json[:fixed_charges].first[:taxes].first).to include(
          lago_id: fixed_charge.applied_taxes.first.tax.id,
          name: fixed_charge.applied_taxes.first.tax.name,
          code: fixed_charge.applied_taxes.first.tax.code,
          rate: fixed_charge.applied_taxes.first.tax.rate
        )
      end
    end

    context "when subscription is not found" do
      let(:external_id_query_param) { "not-found-id" }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("subscription")
      end
    end
  end

  describe "GET /api/v1/subscriptions/:external_id/fixed_charges/:code" do
    subject { get_with_token(organization, "/api/v1/subscriptions/#{external_id_query_param}/fixed_charges/#{fixed_charge.code}") }

    it_behaves_like "requires API permission", "subscription", "read"

    it "returns the fixed charge" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:fixed_charge][:lago_id]).to eq(fixed_charge.id)
      expect(json[:fixed_charge][:code]).to eq(fixed_charge.code)
      expect(json[:fixed_charge][:charge_model]).to eq(fixed_charge.charge_model)
      expect(json[:fixed_charge][:lago_add_on_id]).to eq(fixed_charge.add_on_id)
    end

    context "when subscription does not exist" do
      let(:external_id_query_param) { "invalid_external_id" }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("subscription")
      end
    end

    context "when fixed charge does not exist" do
      subject { get_with_token(organization, "/api/v1/subscriptions/#{external_id_query_param}/fixed_charges/invalid_code") }

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("fixed_charge")
      end
    end

    context "when subscription has plan override with fixed charge override" do
      let(:overridden_plan) { create(:plan, organization:, parent: plan) }
      let(:subscription) { create(:subscription, customer:, plan: overridden_plan, external_id:) }
      let(:overridden_fixed_charge) { create(:fixed_charge, plan: overridden_plan, organization:, add_on:, parent: fixed_charge, code: fixed_charge.code) }

      before { overridden_fixed_charge }

      it "returns the overridden fixed charge" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:fixed_charge][:lago_id]).to eq(overridden_fixed_charge.id)
        expect(json[:fixed_charge][:lago_parent_id]).to eq(fixed_charge.id)
      end
    end

    context "when a per-subscription units override exists" do
      let(:fixed_charge) { create(:fixed_charge, plan:, organization:, add_on:, units: 10) }

      before do
        create(:subscription_fixed_charge_units_override, subscription:, fixed_charge:, organization:, units: 99)
      end

      it "returns the overridden units" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:fixed_charge][:units]).to eq("99.0")
      end
    end
  end

  describe "PUT /api/v1/subscriptions/:external_id/fixed_charges/:code" do
    subject { put_with_token(organization, "/api/v1/subscriptions/#{external_id_query_param}/fixed_charges/#{fixed_charge.code}", {fixed_charge: update_params}) }

    let(:update_params) do
      {
        invoice_display_name: "Updated Fixed Charge Name",
        units: "15"
      }
    end

    context "with premium license", :premium do
      it_behaves_like "requires API permission", "subscription", "write"

      it "creates a plan override and fixed charge override" do
        expect { subject }.to change(Plan, :count).by(1).and change(FixedCharge, :count).by(1)

        expect(response).to have_http_status(:success)
        expect(json[:fixed_charge][:invoice_display_name]).to eq("Updated Fixed Charge Name")
        expect(json[:fixed_charge][:units]).to eq("15.0")
        expect(json[:fixed_charge][:lago_parent_id]).to eq(fixed_charge.id)
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

      context "when fixed charge does not exist" do
        subject { put_with_token(organization, "/api/v1/subscriptions/#{external_id_query_param}/fixed_charges/invalid_code", {fixed_charge: update_params}) }

        it "returns not found error" do
          subject

          expect(response).to be_not_found_error("fixed_charge")
        end
      end

      context "when subscription already has plan override" do
        let(:overridden_plan) { create(:plan, organization:, parent: plan) }
        let(:subscription) { create(:subscription, customer:, plan: overridden_plan, external_id:) }
        let(:overridden_fixed_charge) { create(:fixed_charge, plan: overridden_plan, organization:, add_on:, parent: fixed_charge, code: fixed_charge.code) }

        before { overridden_fixed_charge }

        it "does not create a new plan" do
          expect { subject }.not_to change(Plan, :count)
        end

        it "updates the existing fixed charge override" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:fixed_charge][:lago_id]).to eq(overridden_fixed_charge.id)
          expect(json[:fixed_charge][:invoice_display_name]).to eq("Updated Fixed Charge Name")
          expect(json[:fixed_charge][:units]).to eq("15.0")
        end
      end

      context "with taxes" do
        let(:tax) { create(:tax, organization:) }
        let(:update_params) do
          {
            invoice_display_name: "Taxed Fixed Charge",
            tax_codes: [tax.code]
          }
        end

        it "creates a fixed charge override with taxes" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:fixed_charge][:taxes]).to be_present
          expect(json[:fixed_charge][:taxes].length).to eq(1)
          expect(json[:fixed_charge][:taxes].first[:code]).to eq(tax.code)
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
