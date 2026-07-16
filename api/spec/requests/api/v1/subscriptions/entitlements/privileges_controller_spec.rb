# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Subscriptions::Entitlements::PrivilegesController do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, organization:, customer:, plan:) }
  let(:feature) { create(:feature, organization:, code: "seats") }
  let(:privilege) { create(:privilege, organization:, feature:, code: "max", value_type: "integer") }
  let(:entitlement) { create(:entitlement, subscription: subscription, plan: nil, feature:) }
  let(:entitlement_value) { create(:entitlement_value, entitlement:, privilege:, value: 30) }

  describe "DELETE #destroy" do
    subject { delete_with_token organization, "/api/v1/subscriptions/#{subscription.external_id}/entitlements/#{feature.code}/privileges/#{privilege.code}" }

    before do
      entitlement
      entitlement_value
    end

    it "deletes the entitlement value" do
      expect { subject }.to change(feature.entitlement_values, :count).by(-1)

      expect(response).to have_http_status(:success)
    end

    it "does not delete the entitlement" do
      expect { subject }.not_to change(feature.entitlements, :count)
    end

    it "returns not found error when subscription does not exist" do
      delete_with_token organization, "/api/v1/subscriptions/invalid_subscription/entitlements/#{feature.code}/privileges/#{privilege.code}"

      expect(response).to be_not_found_error("subscription")
    end

    it "returns not found error when feature does not exist" do
      delete_with_token organization, "/api/v1/subscriptions/#{subscription.external_id}/entitlements/invalid_feature/privileges/#{privilege.code}"

      expect(response).to be_not_found_error("feature")
    end

    it "returns not found error when privilege does not exist" do
      delete_with_token organization, "/api/v1/subscriptions/#{subscription.external_id}/entitlements/#{feature.code}/privileges/invalid_privilege"

      expect(response).to be_not_found_error("privilege")
    end

    context "when privilege is from the plan" do
      let(:plan_entitlement) { create(:entitlement, plan:, feature:) }
      let(:plan_entitlement_value) { create(:entitlement_value, entitlement: plan_entitlement, privilege:, value: 10) }

      it "adds a privilege removal" do
        plan_entitlement_value
        expect { subject }.to change(subscription.entitlement_removals.where(privilege:), :count).from(0).to(1)
      end

      context "when privilege removal already exists" do
        before do
          create(:subscription_feature_removal, subscription:, privilege: plan_entitlement_value.privilege)
        end

        it "returns a success" do
          expect(Entitlement::SubscriptionEntitlement.for_subscription(subscription).sole.privileges).to be_empty
          expect { subject }.not_to change(subscription.entitlement_removals.where(privilege:), :count)
          expect(response).to have_http_status(:success)
          expect(json[:entitlements].sole[:privileges]).to be_empty
        end
      end
    end
  end
end
