# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::SubscriptionFeatureRemoveService do
  subject(:result) { described_class.call(subscription:, feature_code:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, organization:, customer:, plan:) }
  let(:feature) { create(:feature, organization:, code: "test_feature") }
  let(:feature_code) { feature.code }

  describe "#call", :premium do
    context "when subscription is nil" do
      let(:subscription) { nil }

      it "returns not found failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("subscription")
      end
    end

    context "when feature is not found" do
      let(:feature_code) { "nonexistent_feature" }

      it "returns not found failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("feature")
      end
    end

    context "when feature is not on subscription or plan" do
      before { feature }

      it "succeeds and returns feature code" do
        expect(result).to be_success
        expect(result.feature_code).to eq(feature_code)
      end

      it "does not create subscription feature removal" do
        expect { result }.not_to change(Entitlement::SubscriptionFeatureRemoval, :count)
      end

      it "sends webhook" do
        expect { result }.to have_enqueued_job_after_commit(SendWebhookJob).with("subscription.updated", subscription)
      end

      it "produces an activity log" do
        result
        expect(Utils::ActivityLog).to have_produced("subscription.updated").after_commit.with(subscription)
      end
    end

    context "when feature is on plan but not on subscription" do
      let(:plan_entitlement) { create(:entitlement, feature:, plan:) }

      before { plan_entitlement }

      it "creates a subscription feature removal" do
        expect { result }.to change(organization.subscription_feature_removals, :count).by(1)

        expect(result).to be_success

        removal = Entitlement::SubscriptionFeatureRemoval.last
        expect(removal.organization).to eq(organization)
        expect(removal.subscription).to eq(subscription)
        expect(removal.feature).to eq(feature)
      end

      context "when the feature is already removed" do
        it "succeeds" do
          create(:subscription_feature_removal, subscription:, feature:)
          expect { result }.not_to change(subscription.entitlement_removals.where(feature:), :count)
          expect(result).to be_success
        end
      end
    end

    context "when feature is on subscription" do
      let(:subscription_entitlement) { create(:entitlement, feature:, subscription:, plan: nil) }
      let(:privilege) { create(:privilege, feature:, code: "max", value_type: "integer") }
      let(:entitlement_value) { create(:entitlement_value, entitlement: subscription_entitlement, privilege:, value: "10") }

      before do
        entitlement_value
        subscription_entitlement.reload
      end

      it "succeeds and returns feature code" do
        expect(result).to be_success
        expect(result.feature_code).to eq(feature_code)
      end

      it "soft deletes the entitlement values" do
        expect { result }.to change { entitlement_value.reload.deleted_at }.from(nil)
      end

      it "discards the subscription entitlement" do
        expect { result }.to change { subscription_entitlement.reload.discarded? }.from(false).to(true)
      end

      context "when feature is also on plan" do
        let(:privilege2) { create(:privilege, feature:, code: "max_admin", value_type: "integer") }
        let(:plan_entitlement) { create(:entitlement, feature:, plan:) }
        let(:plan_entitlement_value2) { create(:entitlement_value, privilege: privilege2, entitlement: plan_entitlement, value: "10") }
        let(:privilege_removal) { create(:subscription_feature_removal, privilege: privilege2, subscription:) }

        before do
          plan_entitlement_value2
          privilege_removal
        end

        it "creates a subscription feature removal" do
          expect { result }.to change(organization.subscription_feature_removals.where(feature:), :count).by(1)

          removal = organization.subscription_feature_removals.order(created_at: :desc).first
          expect(removal.organization).to eq(organization)
          expect(removal.subscription).to eq(subscription)
          expect(removal.feature).to eq(feature)
        end

        it "soft deletes the entitlement values and discards entitlement" do
          expect { result }.to change { entitlement_value.reload.deleted_at }.from(nil)
            .and change { subscription_entitlement.reload.discarded? }.from(false).to(true)
        end

        it "cleans up existing privilege removals" do
          expect { result }.to change { privilege_removal.reload.discarded? }.from(false).to(true)
        end
      end

      context "when plan has parent plan with the feature" do
        let(:parent_plan) { create(:plan, organization:) }
        let(:child_plan) { create(:plan, organization:, parent: parent_plan) }
        let(:subscription) { create(:subscription, organization:, customer:, plan: child_plan) }
        let(:parent_entitlement) { create(:entitlement, feature:, plan: parent_plan) }
        let(:subscription_entitlement) { create(:entitlement, feature:, subscription:, plan: nil) }

        before do
          parent_entitlement
          entitlement_value
          subscription_entitlement.reload
        end

        it "creates a subscription feature removal" do
          expect { result }.to change(Entitlement::SubscriptionFeatureRemoval, :count).by(1)

          removal = Entitlement::SubscriptionFeatureRemoval.last
          expect(removal.organization).to eq(organization)
          expect(removal.subscription).to eq(subscription)
          expect(removal.feature).to eq(feature)
        end
      end
    end
  end
end
