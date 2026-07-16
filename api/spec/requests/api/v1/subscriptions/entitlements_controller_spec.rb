# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Subscriptions::EntitlementsController do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, organization:, customer:, plan:) }
  let(:feature) { create(:feature, organization:, code: "seats") }
  let(:privilege1) { create(:privilege, organization:, feature:, code: "max", value_type: "integer") }
  let(:privilege2) { create(:privilege, organization:, feature:, code: "root?", value_type: "boolean") }

  describe "GET /api/v1/subscriptions/:external_id/entitlements" do
    subject { get_with_token organization, "/api/v1/subscriptions/#{subscription.external_id}/entitlements" }

    let(:entitlement) { create(:entitlement, plan:, feature:) }
    let(:entitlement_value1) { create(:entitlement_value, entitlement:, privilege: privilege1, value: 30) }
    let(:sub_entitlement) { create(:entitlement, subscription_id: subscription.id, plan: nil, feature:) }
    let(:entitlement_value2) { create(:entitlement_value, entitlement: sub_entitlement, privilege: privilege2, value: true) }

    before do
      entitlement_value1
      entitlement_value2
    end

    it "returns a list of entitlements" do
      subject

      expect(response).to have_http_status(:success)
      se = json[:entitlements].sole
      expect(se).to include({
        code: "seats",
        name: "Feature Name",
        description: "Feature Description",
        overrides: {root?: true}
      })
      expect(se[:privileges]).to contain_exactly({
        code: "root?",
        name: nil,
        value_type: "boolean",
        config: {},
        value: true,
        plan_value: nil,
        override_value: true
      }, {
        code: "max",
        name: nil,
        value_type: "integer",
        config: {},
        value: 30,
        plan_value: 30,
        override_value: nil
      })
    end

    it "returns not found error when subscription does not exist" do
      get_with_token organization, "/api/v1/subscriptions/invalid_subscription/entitlements"

      expect(response).to be_not_found_error("subscription")
    end

    context "when there are subscriptions in :active, :pending, and :terminated status" do
      let(:external_id) { "test" }
      let(:active_subscription) { create(:subscription, organization:, customer:, plan:, status: :active, external_id:) }
      let(:pending_subscription) { create(:subscription, organization:, customer:, plan:, status: :pending, external_id:) }
      let(:terminated_subscription) { create(:subscription, organization:, customer:, plan:, status: :terminated, external_id:) }

      let(:sub_entitlement_active) { create(:entitlement, subscription_id: active_subscription.id, plan: nil, feature:) }
      let(:entitlement_value_active) { create(:entitlement_value, entitlement: sub_entitlement_active, privilege: privilege1, value: 100) }
      let(:sub_entitlement_pending) { create(:entitlement, subscription_id: pending_subscription.id, plan: nil, feature:) }
      let(:entitlement_value_pending) { create(:entitlement_value, entitlement: sub_entitlement_pending, privilege: privilege1, value: 200) }
      let(:sub_entitlement_terminated) { create(:entitlement, subscription_id: terminated_subscription.id, plan: nil, feature:) }
      let(:entitlement_value_terminated) { create(:entitlement_value, entitlement: sub_entitlement_terminated, privilege: privilege1, value: 300) }

      before do
        entitlement_value_active
        entitlement_value_pending
        entitlement_value_terminated
      end

      it "returns entitlements for active subscription by default" do
        get_with_token organization, "/api/v1/subscriptions/#{external_id}/entitlements"

        expect(response).to have_http_status(:success)
        expect(json[:entitlements]).to be_present
        expect(json[:entitlements].first[:overrides][:max]).to eq(100)
      end

      it "returns entitlements for pending subscription when subscription_status param is pending" do
        get_with_token organization, "/api/v1/subscriptions/#{external_id}/entitlements", {subscription_status: "pending"}

        expect(response).to have_http_status(:success)
        expect(json[:entitlements]).to be_present
        expect(json[:entitlements].first[:overrides][:max]).to eq(200)
      end

      it "returns entitlements for terminated subscription when subscription_status param is terminated" do
        get_with_token organization, "/api/v1/subscriptions/#{external_id}/entitlements", {subscription_status: "terminated"}

        expect(response).to have_http_status(:success)
        expect(json[:entitlements]).to be_present
        expect(json[:entitlements].first[:overrides][:max]).to eq(300)
      end

      context "when using old status param" do
        it "returns entitlements for pending subscription when status param is pending" do
          get_with_token organization, "/api/v1/subscriptions/#{external_id}/entitlements", {status: "pending"}

          expect(response).to have_http_status(:success)
          expect(json[:entitlements]).to be_present
          expect(json[:entitlements].first[:overrides][:max]).to eq(200)
        end

        it "returns entitlements for terminated subscription when status param is terminated" do
          get_with_token organization, "/api/v1/subscriptions/#{external_id}/entitlements", {status: "terminated"}

          expect(response).to have_http_status(:success)
          expect(json[:entitlements]).to be_present
          expect(json[:entitlements].first[:overrides][:max]).to eq(300)
        end
      end
    end
  end

  describe "PATCH /api/v1/subscriptions/:external_id/entitlements" do
    subject { patch_with_token organization, "/api/v1/subscriptions/#{subscription.external_id}/entitlements", params }

    let(:entitlement) { create(:entitlement, plan: subscription.plan, feature:) }
    let(:entitlement_value) { create(:entitlement_value, entitlement:, privilege: privilege1, value: "10", organization:) }
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
      feature
      privilege1
      entitlement
      entitlement_value
    end

    it "updates existing entitlement value" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:entitlements]).to be_present
      expect(json[:entitlements].length).to eq(1)
      expect(json[:entitlements].first[:privileges].find { it[:code] == "max" }).to include({
        value: 60,
        plan_value: 10,
        override_value: 60
      })
      expect(json[:entitlements].first[:overrides]).to eq({
        max: 60
      })
    end

    it "does not create new entitlement" do
      expect {
        subject
      }.to change(Entitlement::Entitlement, :count).from(1).to(2)
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

    context "when feature was removed via entitlement removal" do
      let(:params) do
        {
          "entitlements" => {
            "seats" => {
              "max" => 10
            }
          }
        }
      end

      it "removes the removal to restore the feature" do
        removal = create(:subscription_feature_removal, feature:, subscription:)
        subject
        expect(removal.reload).to be_discarded
        expect(subscription.entitlements).to be_empty
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

      it "creates new entitlement with value" do
        expect {
          subject
        }.to change(subscription.entitlements, :count).by(1)
        sub_ent = subscription.entitlements.sole
        expect(sub_ent.values.sole.value).to eq("100")
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

    context "when subscription does not exist" do
      it "returns not found error" do
        patch_with_token organization, "/api/v1/subscriptions/invalid_subscription/entitlements", params

        expect(response).to be_not_found_error("subscription")
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
        expect(json[:entitlements].first[:privileges].find { it[:code] == "max" }[:value]).to eq(10)
      end
    end
  end

  describe "DELETE /api/v1/subscriptions/external_id/entitlements/:feature_code" do
    subject { delete_with_token organization, "/api/v1/subscriptions/#{subscription.external_id}/entitlements/#{feature.code}" }

    let(:entitlement) { create(:entitlement, subscription_id: subscription.id, plan: nil, feature:) }
    let(:entitlement_value) { create(:entitlement_value, entitlement:, privilege: privilege1, value: 30, organization:) }

    before do
      entitlement
      entitlement_value
    end

    it "deletes the entitlement and its values" do
      expect { subject }.to change(feature.entitlements, :count).by(-1)
        .and change(feature.entitlement_values, :count).by(-1)

      expect(response).to have_http_status(:success)
    end

    context "when feature is on plan too" do
      let(:plan_entitlement) { create(:entitlement, plan:, feature:) }

      before do
        plan_entitlement
      end

      it "also add a feature removal" do
        subject
        expect(entitlement.reload).to be_discarded
        expect(entitlement_value.reload).to be_discarded
        expect(subscription.entitlement_removals.where(feature:)).to exist
      end

      context "when subscription had privilege removal" do
        it "cleans up the privilege removal" do
          create(:entitlement_value, entitlement: plan_entitlement, privilege: privilege2, value: false)
          privilege_removal = create(:subscription_feature_removal, privilege: privilege2, subscription:)
          subject
          expect(privilege_removal.reload).to be_discarded
          expect(entitlement.reload).to be_discarded
          expect(entitlement_value.reload).to be_discarded
          expect(subscription.entitlement_removals.where(feature:)).to exist
        end
      end

      context "when feature was already removed via entitlement removal" do
        it "returns a success" do
          create(:subscription_feature_removal, feature:, subscription:)
          expect(Entitlement::SubscriptionEntitlement.for_subscription(subscription)).to be_empty
          subject
          expect(response).to have_http_status(:success)
          expect(json[:entitlements]).to be_empty
        end
      end
    end

    it "returns not found error when subscription does not exist" do
      delete_with_token organization, "/api/v1/subscriptions/invalid_subscription/entitlements/#{feature.code}"

      expect(response).to be_not_found_error("subscription")
    end

    it "returns not found error when feature does not exist" do
      delete_with_token organization, "/api/v1/subscriptions/#{subscription.external_id}/entitlements/invalid_feature"

      expect(response).to be_not_found_error("feature")
    end
  end
end
