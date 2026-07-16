# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Plans::Entitlements::PrivilegesController do
  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:feature) { create(:feature, organization:) }
  let(:privilege) { create(:privilege, organization:, feature:, code: "max_users") }
  let(:privilege2) { create(:privilege, organization:, feature:, code: "max_admins") }
  let(:entitlement) { create(:entitlement, organization:, plan:, feature:) }
  let(:entitlement_value) { create(:entitlement_value, entitlement:, privilege:, organization:) }
  let(:entitlement_value2) { create(:entitlement_value, entitlement:, privilege: privilege2, organization:) }

  before do
    entitlement_value
    entitlement_value2
  end

  describe "DELETE #destroy" do
    subject do
      delete_with_token organization, "/api/v1/plans/#{plan.code}/entitlements/#{feature.code}/privileges/#{privilege.code}"
    end

    it "deletes the specific privilege value from the entitlement" do
      expect { subject }.to change(privilege.values, :count).by(-1)

      expect(response).to have_http_status(:success)
      expect(json[:entitlement][:privileges].pluck(:code)).to eq(["max_admins"])
    end

    it "returns not found error when plan does not exist" do
      delete_with_token organization, "/api/v1/plans/invalid_plan/entitlements/#{feature.code}/privileges/#{privilege.code}"

      expect(response).to be_not_found_error("plan")
    end

    it "returns not found error when entitlement does not exist" do
      delete_with_token organization, "/api/v1/plans/#{plan.code}/entitlements/invalid_feature/privileges/#{privilege.code}"

      expect(response).to be_not_found_error("entitlement")
    end

    it "returns not found error when privilege does not exist" do
      delete_with_token organization, "/api/v1/plans/#{plan.code}/entitlements/#{feature.code}/privileges/invalid_privilege"

      expect(response).to be_not_found_error("privilege")
    end

    it "returns the updated entitlement in the response" do
      subject

      expect(response).to have_http_status(:success)

      json = JSON.parse(response.body, symbolize_names: true)
      expect(json[:entitlement][:code]).to eq(feature.code)
      expect(json[:entitlement][:privileges].sole).to include({
        code: "max_admins",
        value: entitlement_value2.value
      })
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
end
