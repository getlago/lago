# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Plans::EntitlementsController do
  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:feature) { create(:feature, organization:, code: "seats") }
  let(:privilege) { create(:privilege, organization:, feature:, code: "max", value_type: "integer") }

  describe "GET /api/v1/plans/:plan_code/entitlements" do
    subject { get_with_token organization, "/api/v1/plans/#{plan.code}/entitlements" }

    let(:entitlement) { create(:entitlement, organization:, plan:, feature:) }
    let(:entitlement_value) { create(:entitlement_value, entitlement:, privilege:, value: 30, organization:) }

    before do
      entitlement
      entitlement_value
    end

    it "returns a list of entitlements" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:entitlements]).to be_present
      expect(json[:entitlements].length).to eq(1)
      expect(json[:entitlements].first[:privileges].sole[:value]).to eq(30)
    end

    context "when plan has children (subscription plan overrides)" do
      it "always retrieve the parent plan" do
        # NOTE: It should be possible to create entitlements on a child plan,
        #       but we want to tests that the controller retrieves only parents
        override = create(:plan, organization:, code: plan.code, parent: plan)
        override_entitlement = create(:entitlement, plan: override, feature:)
        create(:entitlement_value, entitlement: override_entitlement, privilege:, value: 999, organization:)

        plan.update! deleted_at: Time.current

        subject

        expect(response).to have_http_status(:not_found)
        expect(json[:code]).to eq "plan_not_found"
      end
    end
  end

  describe "GET /api/v1/plans/:plan_code/entitlements/:feature_code" do
    subject { get_with_token organization, "/api/v1/plans/#{plan.code}/entitlements/#{feature.code}" }

    let(:entitlement) { create(:entitlement, organization:, plan:, feature:) }
    let(:entitlement_value) { create(:entitlement_value, entitlement:, privilege:, value: 30, organization:) }

    before do
      entitlement
      entitlement_value
    end

    it "returns the entitlement" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:entitlement][:code]).to eq("seats")
      expect(json[:entitlement][:privileges].sole[:value]).to eq(30)
    end

    it "returns not found error when plan does not exist" do
      get_with_token organization, "/api/v1/plans/invalid_plan/entitlements/#{feature.code}"

      expect(response).to be_not_found_error("plan")
    end

    it "returns not found error when entitlement does not exist" do
      get_with_token organization, "/api/v1/plans/#{plan.code}/entitlements/invalid_feature"

      expect(response).to be_not_found_error("entitlement")
    end
  end

  describe "POST /api/v1/plans/:plan_code/entitlements" do
    subject { post_with_token organization, "/api/v1/plans/#{plan.code}/entitlements", params }

    let(:params) do
      {
        "entitlements" => {
          "seats" => {
            "max" => 25
          }
        }
      }
    end

    before do
      feature
      privilege
    end

    it "creates entitlements for the plan" do
      expect { subject }.to change { plan.entitlements.count }.by(1)
        .and change(Entitlement::EntitlementValue, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(json[:entitlements]).to be_present
      expect(json[:entitlements].length).to eq(1)
      expect(json[:entitlements].first[:privileges].sole[:value]).to eq(25)
    end

    context "when plan has existing entitlements" do
      let(:existing_entitlement) { create(:entitlement, organization:, plan:, feature:) }
      let(:existing_value) { create(:entitlement_value, entitlement: existing_entitlement, privilege:, value: "10", organization:) }

      before do
        existing_entitlement
        existing_value
      end

      it "replaces existing entitlements" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:entitlements].first[:privileges].sole[:value]).to eq(25)
      end
    end

    context "when feature does not exist" do
      let(:params) do
        {
          entitlements: {
            "nonexistent_feature" => {
              "max" => 25
            }
          }
        }
      end

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("feature")
      end
    end

    context "when privilege does not exist" do
      let(:params) do
        {
          entitlements: {
            "seats" => {
              "nonexistent_privilege" => 25
            }
          }
        }
      end

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("privilege")
      end
    end

    context "when privilege value is invalid" do
      let(:params) do
        {
          entitlements: {
            "seats" => {
              "max" => [12, 13]
            }
          }
        }
      end

      it "returns not found error" do
        subject

        expect(response).to have_http_status(:unprocessable_content)
        expect(json[:code]).to eq("validation_errors")
        expect(json[:error_details][:max_privilege_value]).to eq(["value_is_invalid"])
      end
    end

    context "when privilege value is not in select_options" do
      let(:params) do
        {
          entitlements: {
            "seats" => {
              "invitation" => "okta"
            }
          }
        }
      end

      before do
        config = {select_options: ["email", "phone", "slack"]}
        create(:privilege, organization:, feature:, code: "invitation", value_type: "select", config:)
      end

      it "returns not found error" do
        subject

        expect(response).to have_http_status(:unprocessable_content)
        expect(json[:code]).to eq("validation_errors")
        expect(json[:error_details][:invitation_privilege_value]).to eq(["value_not_in_select_options"])
      end
    end

    context "when plan does not exist" do
      it "returns not found error" do
        post_with_token organization, "/api/v1/plans/invalid_plan/entitlements", params

        expect(response).to be_not_found_error("plan")
      end
    end

    context "when entitlements params is empty" do
      let(:params) do
        {
          entitlements: {}
        }
      end

      it "returns success with empty entitlements" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:entitlements]).to eq([])
      end
    end

    context "when feature has multiple privileges" do
      let(:privilege2) { create(:privilege, organization:, feature:, code: "max_admins", value_type: "integer") }
      let(:params) do
        {
          entitlements: {
            "seats" => {
              "max" => 25,
              "max_admins" => 5
            }
          }
        }
      end

      before do
        privilege2
      end

      it "creates entitlement values for all privileges" do
        expect { subject }.to change(Entitlement::EntitlementValue, :count).by(2)

        expect(response).to have_http_status(:success)
        expect(json[:entitlements].first[:privileges]).to contain_exactly({
          code: "max",
          name: nil,
          value_type: "integer",
          value: 25,
          config: {}
        }, {
          code: "max_admins",
          name: nil,
          value_type: "integer",
          value: 5,
          config: {}
        })
      end
    end
  end

  describe "PATCH /api/v1/plans/:plan_code/entitlements" do
    subject { patch_with_token organization, "/api/v1/plans/#{plan.code}/entitlements", params }

    let(:entitlement) { create(:entitlement, organization:, plan:, feature:) }
    let(:entitlement_value) { create(:entitlement_value, entitlement:, privilege:, value: "10", organization:) }
    let(:params) do
      {
        "entitlements" => {
          "seats" => {
            "max" => 60
          }
        }
      }
    end

    before do
      entitlement
      entitlement_value
    end

    it "updates existing entitlement value" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:entitlements]).to be_present
      expect(json[:entitlements].length).to eq(1)
      expect(json[:entitlements].first[:privileges].sole[:value]).to eq(60)
    end

    it "does not create new entitlement" do
      expect {
        subject
      }.not_to change(Entitlement::Entitlement, :count)
    end

    context "when privilege value does not exist" do
      let(:privilege2) { create(:privilege, organization:, feature:, code: "max_admins", value_type: "integer") }
      let(:params) do
        {
          "entitlements" => {
            "seats" => {
              "max_admins" => 30
            }
          }
        }
      end

      before do
        privilege2
      end

      it "creates new entitlement value" do
        expect {
          subject
        }.to change(Entitlement::EntitlementValue, :count).by(1)
      end

      it "creates entitlement value with correct value" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:entitlements].first[:privileges].find { it[:code] == "max_admins" }[:value]).to eq(30)
      end
    end

    context "when privilege value is invalid" do
      let(:params) do
        {
          "entitlements" => {
            "seats" => {
              "max" => "one thousand!!"
            }
          }
        }
      end

      it "returns a validation error" do
        subject

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json[:error_details][:max_privilege_value]).to eq(["value_is_invalid"])
      end
    end

    context "when entitlement does not exist" do
      let(:new_feature) { create(:feature, organization:, code: "storage") }
      let(:new_privilege) { create(:privilege, organization:, feature: new_feature, code: "max_gb", value_type: "integer") }
      let(:params) do
        {
          "entitlements" => {
            "storage" => {
              "max_gb" => 100
            }
          }
        }
      end

      before do
        new_feature
        new_privilege
      end

      it "creates new entitlement" do
        expect {
          subject
        }.to change(Entitlement::Entitlement, :count).by(1)
      end

      it "creates new entitlement value" do
        expect {
          subject
        }.to change(Entitlement::EntitlementValue, :count).by(1)
      end
    end

    context "when feature does not exist" do
      let(:params) do
        {
          "entitlements" => {
            "nonexistent_feature" => {
              "max" => 60
            }
          }
        }
      end

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("feature")
      end
    end

    context "when privilege does not exist" do
      let(:params) do
        {
          "entitlements" => {
            "seats" => {
              "nonexistent_privilege" => 60
            }
          }
        }
      end

      it "returns not found error" do
        subject

        expect(response).to be_not_found_error("privilege")
      end
    end

    context "when plan does not exist" do
      it "returns not found error" do
        patch_with_token organization, "/api/v1/plans/invalid_plan/entitlements", params

        expect(response).to be_not_found_error("plan")
      end
    end

    context "when entitlements params is empty" do
      let(:params) do
        {
          "entitlements" => {}
        }
      end

      it "returns success with existing entitlements" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:entitlements]).to be_present
        expect(json[:entitlements].first[:privileges].sole[:value]).to eq(10)
      end
    end
  end

  describe "DELETE /api/v1/plans/:plan_code/entitlements/:feature_code" do
    subject { delete_with_token organization, "/api/v1/plans/#{plan.code}/entitlements/#{feature.code}" }

    let(:entitlement) { create(:entitlement, organization:, plan:, feature:) }
    let(:entitlement_value) { create(:entitlement_value, entitlement:, privilege:, value: 30, organization:) }

    before do
      entitlement
      entitlement_value
    end

    it "deletes the entitlement and its values" do
      expect { subject }.to change(feature.entitlements, :count).by(-1)
        .and change(feature.entitlement_values, :count).by(-1)

      expect(response).to have_http_status(:success)
      expect(json[:entitlement][:code]).to eq "seats"
      expect(json[:entitlement][:privileges].sole[:code]).to eq "max"
    end

    it "returns not found error when plan does not exist" do
      delete_with_token organization, "/api/v1/plans/invalid_plan/entitlements/#{feature.code}"

      expect(response).to be_not_found_error("plan")
    end

    it "returns not found error when entitlement does not exist" do
      delete_with_token organization, "/api/v1/plans/#{plan.code}/entitlements/invalid_feature"

      expect(response).to be_not_found_error("entitlement")
    end
  end
end
