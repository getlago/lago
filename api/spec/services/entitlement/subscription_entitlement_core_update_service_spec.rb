# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::SubscriptionEntitlementCoreUpdateService do
  subject(:result) { described_class.call(subscription:, plan:, feature: seats, plan_entitlement:, sub_entitlement:, privilege_params:, partial:) }

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, organization:, plan:) }

  let(:plan_entitlement) { plan.entitlements.includes(values: :privilege).find_by(feature: seats) }
  let(:sub_entitlement) { subscription.entitlements.includes(values: :privilege).find_by(feature: seats) }

  let(:seats) { create(:feature, organization:, code: "seats", name: "Nb users") }
  let(:seats_max) { create(:privilege, feature: seats, code: "max", name: "Max", value_type: "integer") }
  let(:seats_reset) { create(:privilege, feature: seats, code: "reset", name: "Password Reset", value_type: "boolean") }
  let(:seats_signin) { create(:privilege, feature: seats, code: "signin", name: "Sign In", value_type: "select", config: {select_options: ["password", "okta"]}) }

  let(:same_code_feature) { create(:feature, organization: create(:organization), code: "seats", name: "Nb users") }

  before do
    seats_reset
    seats_max
    same_code_feature
  end

  def expect_entitlement_to_match(privilege_params)
    ent = Entitlement::SubscriptionEntitlement.for_subscription(subscription).find { it.code == "seats" }
    ent_values = ent.privileges.map do |priv|
      [priv.code, Utils::Entitlement.cast_value(priv.value, priv.value_type)]
    end.to_h
    expect(ent_values).to eq privilege_params
  end

  describe "#call" do
    context "when plan has no feature" do
      context "when subscription has no feature" do
        let(:privilege_params) { {seats_max.code => 100, seats_reset.code => true} }

        context "when partial" do
          let(:partial) { true }

          it "adds the feature to the subscription" do
            expect(result).to be_success
            expect_entitlement_to_match(privilege_params)
            sub_ent = subscription.entitlements.includes(values: :privilege).sole
            expect(sub_ent.feature).to eq seats
            expect(sub_ent.values.count).to eq 2
            expect(sub_ent.values.map { it.privilege.code }).to match_array privilege_params.keys
          end
        end

        context "when full" do
          let(:partial) { false }

          it "adds the feature to the subscription" do
            expect(result).to be_success
            expect_entitlement_to_match(privilege_params)
            sub_ent = subscription.entitlements.includes(values: :privilege).sole
            expect(sub_ent.feature).to eq seats
            expect(sub_ent.values.count).to eq 2
            expect(sub_ent.values.map { it.privilege.code }).to match_array privilege_params.keys
          end
        end
      end

      context "when subscription already has feature" do
        let(:privilege_params) { {seats_max.code => 100, seats_reset.code => true} }
        let(:sub_entitlement) { create(:entitlement, subscription:, plan: nil, feature: seats) }
        let(:max_value) { create(:entitlement_value, entitlement: sub_entitlement, privilege: seats_max, value: 2) }
        let(:reset_value) { create(:entitlement_value, entitlement: sub_entitlement, privilege: seats_reset, value: false) }
        let(:signin_value) { create(:entitlement_value, entitlement: sub_entitlement, privilege: seats_signin, value: "okta") }

        before do
          max_value
          reset_value
          signin_value
        end

        context "when partial" do
          let(:partial) { true }

          it "updates the existing values" do
            expect(result).to be_success
            expect_entitlement_to_match(privilege_params.merge(seats_signin.code => "okta"))
            expect(subscription.entitlements.count).to eq 1
            expect(max_value.reload.value).to eq "100"
            expect(reset_value.reload.value).to eq "t"
            expect(signin_value.reload.value).to eq "okta"
            expect(signin_value).not_to be_discarded
          end
        end

        context "when full" do
          let(:partial) { false }

          it "adds the feature to the subscription" do
            expect(result).to be_success
            expect_entitlement_to_match(privilege_params)
            expect(subscription.entitlements.count).to eq 1
            expect(max_value.reload.value).to eq "100"
            expect(reset_value.reload.value).to eq "t"
            expect(signin_value.reload).to be_discarded
          end
        end
      end
    end

    context "when plan has the feature" do
      let(:privilege_params) { {seats_max.code => 100, seats_reset.code => true} }

      let(:plan_entitlement) { create(:entitlement, plan:, feature: seats) }
      let(:max_value) { create(:entitlement_value, entitlement: plan_entitlement, privilege: seats_max, value: 2) }
      let(:reset_value) { create(:entitlement_value, entitlement: plan_entitlement, privilege: seats_reset, value: false) }
      let(:signin_value) { create(:entitlement_value, entitlement: plan_entitlement, privilege: seats_signin, value: "okta") }

      # Create discarded feature and privilege removal
      let(:discarded_seats_removal) { create(:subscription_feature_removal, feature: seats, subscription:, deleted_at: 1.day.ago) }
      let(:discarded_max_removal) { create(:subscription_feature_removal, privilege: seats_max, subscription:, deleted_at: 1.day.ago) }
      let(:discarded_reset_removal) { create(:subscription_feature_removal, privilege: seats_reset, subscription:, deleted_at: 1.day.ago) }
      let(:discarded_signin_removal) { create(:subscription_feature_removal, privilege: seats_signin, subscription:, deleted_at: 1.day.ago) }

      before do
        max_value
        reset_value
        signin_value
        discarded_seats_removal
        discarded_max_removal
        discarded_reset_removal
        discarded_signin_removal
      end

      context "when privilege_params match plan values in a different order" do
        let(:privilege_params) { {seats_signin.code => "okta", seats_reset.code => false, seats_max.code => 2} }

        context "when subscription has no overrides" do
          let(:partial) { false }

          it "removes subscription overrides and restores plan defaults" do
            expect(result).to be_success
            expect(subscription.entitlements.count).to eq 0
          end
        end

        context "when subscription already has overrides" do
          let(:partial) { false }
          let(:sub_entitlement) { create(:entitlement, feature: seats, subscription:, plan: nil) }
          let(:sub_max_value) { create(:entitlement_value, entitlement: sub_entitlement, privilege: seats_max, value: 50) }

          before { sub_max_value }

          it "discards subscription entitlement and restores plan defaults" do
            expect(result).to be_success
            expect(sub_entitlement.reload).to be_discarded
            expect(sub_max_value.reload).to be_discarded
          end
        end
      end

      context "when subscription has no entitlements" do
        context "when partial" do
          let(:partial) { true }

          it "adds overrides to the subscription" do
            expect(result).to be_success
            expect_entitlement_to_match(privilege_params.merge(seats_signin.code => "okta"))
            sub_ent = subscription.entitlements.includes(values: :privilege).sole
            expect(sub_ent.values.map(&:value)).to contain_exactly("100", "t")
            expect(sub_ent.values.map { it.privilege.code }).to contain_exactly(seats_max.code, seats_reset.code)
          end
        end

        context "when full" do
          let(:partial) { false }

          it "adds overrides to the subscription and create a privilege removal" do
            expect(result).to be_success
            expect_entitlement_to_match(privilege_params)
            sub_ent = subscription.entitlements.includes(values: :privilege).sole
            expect(sub_ent.values.map(&:value)).to contain_exactly("100", "t")
            expect(sub_ent.values.map { it.privilege.code }).to contain_exactly(seats_max.code, seats_reset.code)

            expect(subscription.entitlement_removals.count).to eq 1
            expect(subscription.entitlement_removals.where(privilege: seats_signin)).to exist
          end
        end
      end

      context "when subscription already has overrides" do
        let(:sub_entitlement) { create(:entitlement, feature: seats, subscription:, plan: nil) }
        let(:sub_max_value) { create(:entitlement_value, entitlement: sub_entitlement, privilege: seats_max, value: 50) }
        let(:sub_signin_value) { create(:entitlement_value, entitlement: sub_entitlement, privilege: seats_signin, value: "password") }

        before do
          sub_max_value
          sub_signin_value
        end

        context "when partial" do
          let(:partial) { true }

          it "adds overrides to the subscription" do
            expect(result).to be_success
            expect_entitlement_to_match(privilege_params.merge(seats_signin.code => "password"))
            expect(subscription.entitlements.count).to eq 1
            expect(sub_max_value.reload.value).to eq "100"
            expect(sub_entitlement.values.map(&:value)).to contain_exactly("100", "t", "password")
            expect(sub_entitlement.values.map { it.privilege.code }).to contain_exactly(seats_max.code, seats_reset.code, seats_signin.code)
          end
        end

        context "when full" do
          let(:partial) { false }

          it "adds overrides to the subscription and create a privilege removal" do
            expect(result).to be_success
            expect_entitlement_to_match(privilege_params)
            sub_ent = subscription.entitlements.includes(values: :privilege).sole
            expect(sub_ent.values.map(&:value)).to contain_exactly("100", "t")
            expect(sub_ent.values.map { it.privilege.code }).to contain_exactly(seats_max.code, seats_reset.code)

            expect(subscription.entitlement_removals.count).to eq 1
            expect(subscription.entitlement_removals.where(privilege: seats_signin)).to exist
            expect(sub_signin_value.reload).to be_discarded
          end
        end
      end

      context "when re-adding a removed privilege at the plan default value" do
        let(:privilege_params) { {seats_max.code => 2} }
        let(:max_removal) { create(:subscription_feature_removal, privilege: seats_max, subscription:) }

        before { max_removal }

        context "when partial" do
          let(:partial) { true }

          it "discards the privilege removal so the plan default is restored" do
            expect(result).to be_success
            expect(max_removal.reload).to be_discarded
            expect(subscription.entitlement_removals.where(privilege: seats_max)).not_to exist

            ent = Entitlement::SubscriptionEntitlement.for_subscription(subscription).find { it.code == "seats" }
            max_priv = ent.privileges.find { it.code == seats_max.code }
            expect(Utils::Entitlement.cast_value(max_priv.value, max_priv.value_type)).to eq 2
          end
        end
      end

      context "when subscription has privilege removals" do
        let(:max_removal) { create(:subscription_feature_removal, privilege: seats_max, subscription:) }
        let(:reset_removal) { create(:subscription_feature_removal, privilege: seats_reset, subscription:) }
        let(:signin_removal) { create(:subscription_feature_removal, privilege: seats_signin, subscription:) }

        before do
          max_removal
          reset_removal
          signin_removal
        end

        context "when partial" do
          let(:partial) { true }

          it "adds overrides to the subscription" do
            expect(result).to be_success
            expect_entitlement_to_match(privilege_params)
            expect(subscription.entitlements.count).to eq 1

            sub_entitlement = subscription.entitlements.includes(values: :privilege).sole
            expect(sub_entitlement.values.map(&:value)).to contain_exactly("100", "t")
            expect(sub_entitlement.values.map { it.privilege.code }).to contain_exactly(seats_max.code, seats_reset.code)

            expect(max_removal.reload).to be_discarded
            expect(reset_removal.reload).to be_discarded

            # QUESTION: Feature is not in plan, should this be cleaned up?
            expect(signin_removal.reload).not_to be_discarded
          end
        end

        context "when full" do
          let(:partial) { false }

          it "adds overrides to the subscription" do
            expect(result).to be_success
            expect_entitlement_to_match(privilege_params)
            expect(subscription.entitlements.count).to eq 1

            sub_entitlement = subscription.entitlements.includes(values: :privilege).sole
            expect(sub_entitlement.values.map(&:value)).to contain_exactly("100", "t")
            expect(sub_entitlement.values.map { it.privilege.code }).to contain_exactly(seats_max.code, seats_reset.code)

            expect(max_removal.reload).to be_discarded
            expect(reset_removal.reload).to be_discarded

            # QUESTION: Feature is not in plan, should this be cleaned up?
            expect(signin_removal.reload).not_to be_discarded
          end
        end
      end
    end
  end
end
