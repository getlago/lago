# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::SubscriptionResolver do
  let(:required_permission) { "subscriptions:view" }
  let(:query) do
    <<~GQL
      query($subscriptionId: ID, $externalId: ID) {
        subscription(id: $subscriptionId, externalId: $externalId) {
          id
          externalId
          name
          startedAt
          endingAt
          progressiveBillingDisabled
          plan {
            id
            code
          }
          nextSubscriptionType
          nextSubscriptionAt
          downgradePlanDate
          previousPlan {
            id
            name
          }
          previousSubscription {
            id
            downgradePlanDate
          }
          usageThresholds { amountCents thresholdDisplayName recurring }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:) }

  before do
    customer
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "subscriptions:view"

  context "when id and external_id are not provided" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      expect_graphql_error(
        result:,
        message: "You must provide either `id` or `external_id`."
      )
    end
  end

  context "when external_id is provided" do
    it "returns a single subscription" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {
          externalId: subscription.external_id
        }
      )

      subscription_response = result["data"]["subscription"]
      expect(subscription_response["id"]).to eq(subscription.id)
      expect(subscription_response["externalId"]).to eq(subscription.external_id)
      expect(subscription_response["usageThresholds"]).to be_an(Array).and be_empty
    end
  end

  it "returns a single subscription" do
    threshold = create(:usage_threshold, :for_subscription, subscription:, amount_cents: 99_00)

    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {subscriptionId: subscription.id}
    )

    subscription_response = result["data"]["subscription"]
    expect(subscription_response).to include(
      "id" => subscription.id,
      "name" => subscription.name,
      "startedAt" => subscription.started_at.iso8601,
      "endingAt" => subscription.ending_at,
      "progressiveBillingDisabled" => false
    )

    expect(subscription_response["plan"]).to include(
      "id" => subscription.plan.id,
      "code" => subscription.plan.code
    )

    expect(subscription_response["usageThresholds"]).to contain_exactly({
      "amountCents" => "9900",
      "thresholdDisplayName" => threshold.threshold_display_name,
      "recurring" => false
    })
  end

  context "when subscription is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {subscriptionId: "foo"}
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end

  context "when subscription has a pending downgrade" do
    let(:plan) { create(:plan, organization:, amount_cents: 500_00) }
    let(:lower_plan) { create(:plan, organization:, amount_cents: 100_00) }
    let(:subscription) do
      create(:subscription, :anniversary, customer:, plan:, subscription_at: Time.zone.parse("2026-04-22 00:00:00"), started_at: Time.zone.parse("2026-04-22 00:00:00"))
    end
    let(:pending_subscription) do
      create(:subscription, :pending, customer:, plan: lower_plan, previous_subscription: subscription)
    end

    before { pending_subscription }

    it "returns downgradePlanDate computed from the current billing period" do
      travel_to Time.zone.parse("2026-04-25 12:00:00") do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query:,
          variables: {subscriptionId: subscription.id}
        )

        subscription_response = result["data"]["subscription"]
        expect(subscription_response["downgradePlanDate"]).to eq("2026-05-22")
        expect(subscription_response["nextSubscriptionType"]).to eq("downgrade")
      end
    end

    it "exposes previousPlan and previousSubscription.downgradePlanDate on the pending subscription" do
      travel_to Time.zone.parse("2026-04-25 12:00:00") do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query:,
          variables: {subscriptionId: pending_subscription.id}
        )

        subscription_response = result["data"]["subscription"]
        expect(subscription_response["previousPlan"]).to include(
          "id" => plan.id,
          "name" => plan.name
        )
        expect(subscription_response["downgradePlanDate"]).to be_nil
        expect(subscription_response["previousSubscription"]).to include(
          "id" => subscription.id,
          "downgradePlanDate" => "2026-05-22"
        )
      end
    end
  end

  context "when subscription has no previous subscription" do
    it "returns null for previousPlan, previousSubscription and downgradePlanDate" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {subscriptionId: subscription.id}
      )

      subscription_response = result["data"]["subscription"]
      expect(subscription_response["previousPlan"]).to be_nil
      expect(subscription_response["previousSubscription"]).to be_nil
      expect(subscription_response["downgradePlanDate"]).to be_nil
    end
  end

  context "when subscription was upgraded" do
    let(:subscription) { create(:subscription, :terminated, customer:, next_subscriptions: [next_subscription], terminated_at: 1.day.ago, external_id: next_subscription.external_id) }
    let(:next_subscription) { create(:subscription, customer: customer, plan: create(:plan, amount_cents: 33000_00)) }

    it do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {subscriptionId: subscription.id}
      )

      subscription_response = result["data"]["subscription"]
      expect(subscription_response["nextSubscriptionType"]).to eq "upgrade"
      expect(subscription_response["nextSubscriptionAt"]).to be_present
    end
  end

  context "with fixed_charges field" do
    let(:query) do
      <<~GQL
        query($id: ID!) {
          subscription(id: $id) {
            id
            fixedCharges { id units }
          }
        }
      GQL
    end

    let(:plan) { create(:plan, organization:) }
    let(:add_on) { create(:add_on, organization:) }
    let(:subscription) { create(:subscription, customer:, plan:) }
    let(:fixed_charge) { create(:fixed_charge, plan:, organization:, add_on:, units: 10) }

    context "without a per-subscription override" do
      before { fixed_charge }

      it "returns the plan-level units" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query:,
          variables: {id: subscription.id}
        )

        units = result["data"]["subscription"]["fixedCharges"].first["units"]
        expect(units).to eq("10")
      end
    end

    context "with a per-subscription override" do
      before do
        create(:subscription_fixed_charge_units_override, subscription:, fixed_charge:, organization:, units: 42)
      end

      it "returns the overridden units" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query:,
          variables: {id: subscription.id}
        )

        units = result["data"]["subscription"]["fixedCharges"].first["units"]
        expect(units).to eq("42")
      end
    end
  end

  context "with billing_entity_id field" do
    let(:query) do
      <<~GQL
        query($id: ID!) {
          subscription(id: $id) {
            id
            billingEntityId
          }
        }
      GQL
    end

    context "when the subscription is bound to a billing entity" do
      let(:billing_entity) { create(:billing_entity, organization:) }
      let(:subscription) { create(:subscription, customer:, billing_entity:) }

      it "returns the billing_entity_id" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query:,
          variables: {id: subscription.id}
        )

        expect(result["data"]["subscription"]["billingEntityId"]).to eq(billing_entity.id)
      end
    end

    context "when the subscription has no billing entity (legacy row)" do
      let(:subscription) { create(:subscription, customer:, billing_entity: nil) }

      it "returns null without falling back to the customer's entity" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query:,
          variables: {id: subscription.id}
        )

        expect(result["data"]["subscription"]["billingEntityId"]).to be_nil
      end
    end
  end
end
