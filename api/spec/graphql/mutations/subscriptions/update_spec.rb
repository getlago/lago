# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Subscriptions::Update, :premium do
  subject { execute_query(query:, input:) }

  let(:required_permission) { "subscriptions:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:plan) { create(:plan, organization:) }
  let(:fixed_charge) { create(:fixed_charge, plan:) }

  let(:subscription) do
    create(
      :subscription,
      organization:,
      plan:,
      subscription_at: Time.current + 3.days
    )
  end

  let(:query) do
    <<~GQL
      mutation($input: UpdateSubscriptionInput!) {
        updateSubscription(input: $input) {
          id
          name
          subscriptionAt
          progressiveBillingDisabled
          plan {
            fixedCharges {
              invoiceDisplayName
              units
            }
          }
        }
      }
    GQL
  end
  let(:input) do
    {
      id: subscription.id,
      name: "New name",
      progressiveBillingDisabled: true,
      planOverrides: {
        fixedCharges: [
          {
            id: fixed_charge.id,
            invoiceDisplayName: "NEW fixed charge display name",
            units: "99",
            applyUnitsImmediately: true
          }
        ]
      }
    }
  end

  before do
    plan
    fixed_charge
    subscription
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires permission", "subscriptions:update"

  it "updates an subscription" do
    result = subject

    result_data = result["data"]["updateSubscription"]

    expect(result_data["name"]).to eq("New name")
    expect(result_data["progressiveBillingDisabled"]).to be(true)

    expect(result_data["plan"]["fixedCharges"].first).to include(
      "invoiceDisplayName" => "NEW fixed charge display name",
      "units" => "99"
    )
  end

  context "when subscription is active" do
    let(:subscription) { create(:subscription, plan:, organization:) }

    it "emits a fixed charge event" do
      expect { subject }.to change(FixedChargeEvent, :count).by(1)

      expect(FixedChargeEvent.first).to have_attributes(units: BigDecimal("99"))
    end
  end

  context "when updating only usage_thresholds" do
    let(:query) do
      <<~GQL
        mutation($input: UpdateSubscriptionInput!) {
          updateSubscription(input: $input) {
            id
            usageThresholds {
              id
              amountCents
              thresholdDisplayName
              recurring
            }
          }
        }
      GQL
    end
    let(:input) do
      {
        id: subscription.id,
        usageThresholds: [
          {
            amountCents: 10_000,
            thresholdDisplayName: "First threshold"
          },
          {
            amountCents: 50_000,
            thresholdDisplayName: "Second threshold",
            recurring: true
          }
        ]
      }
    end

    before { organization.update!(premium_integrations: ["progressive_billing"]) }

    it "updates the usage thresholds" do
      result = subject

      result_data = result["data"]["updateSubscription"]
      thresholds = result_data["usageThresholds"]

      expect(thresholds.size).to eq(2)
      expect(thresholds).to match_array([
        hash_including(
          "id" => String,
          "amountCents" => "10000",
          "thresholdDisplayName" => "First threshold",
          "recurring" => false
        ),
        hash_including(
          "id" => String,
          "amountCents" => "50000",
          "thresholdDisplayName" => "Second threshold",
          "recurring" => true
        )
      ])
    end
  end

  context "with activation rules" do
    before { create(:payment_method, customer: subscription.customer, organization:) }

    let(:query) do
      <<~GQL
        mutation($input: UpdateSubscriptionInput!) {
          updateSubscription(input: $input) {
            id
            activationRules {
              id
              type
              timeoutHours
              status
              expiresAt
            }
          }
        }
      GQL
    end

    context "when subscription is pending" do
      let(:subscription) { create(:subscription, :pending, organization:, plan:, subscription_at: Time.current + 3.days) }
      let(:input) do
        {
          id: subscription.id,
          activationRules: [
            {type: "payment", timeoutHours: 24}
          ]
        }
      end

      it "persists and returns activation rules" do
        result = subject

        result_data = result["data"]["updateSubscription"]

        expect(result_data["activationRules"].size).to eq(1)
        expect(result_data["activationRules"].first).to include(
          "id" => String,
          "type" => "payment",
          "timeoutHours" => 24,
          "status" => "inactive",
          "expiresAt" => nil
        )
      end
    end

    context "when removing activation rules with empty array" do
      let(:subscription) { create(:subscription, :pending, :with_activation_rules, organization:, plan:, subscription_at: Time.current + 3.days) }
      let(:input) do
        {
          id: subscription.id,
          activationRules: []
        }
      end

      it "removes all activation rules" do
        result = subject

        result_data = result["data"]["updateSubscription"]

        expect(result_data["activationRules"]).to be_empty
      end
    end

    context "when updating existing activation rules" do
      let(:subscription) { create(:subscription, :pending, :with_activation_rules, organization:, plan:, subscription_at: Time.current + 3.days) }
      let(:input) do
        {
          id: subscription.id,
          activationRules: [
            {type: "payment", timeoutHours: 72}
          ]
        }
      end

      it "replaces activation rules with new values" do
        result = subject

        result_data = result["data"]["updateSubscription"]

        expect(result_data["activationRules"].size).to eq(1)
        expect(result_data["activationRules"].first).to include(
          "id" => String,
          "type" => "payment",
          "timeoutHours" => 72,
          "status" => "inactive",
          "expiresAt" => nil
        )
      end
    end

    context "when subscription is active" do
      let(:subscription) { create(:subscription, organization:, plan:) }
      let(:input) do
        {
          id: subscription.id,
          activationRules: [
            {type: "payment", timeoutHours: 24}
          ]
        }
      end

      it "returns a validation error" do
        result = subject

        expect(result["errors"].first.dig("extensions", "details", "activationRules")).to include("subscription_not_pending")
      end
    end
  end

  context "when moving to a different billing entity" do
    let(:subscription) { create(:subscription, organization:, plan:) }
    let(:new_billing_entity) { create(:billing_entity, organization:) }

    let(:query) do
      <<~GQL
        mutation($input: UpdateSubscriptionInput!) {
          updateSubscription(input: $input) {
            id
            billingEntityId
          }
        }
      GQL
    end

    let(:input) { {id: subscription.id, billingEntityId: new_billing_entity.id} }

    before { organization.update!(feature_flags: ["multi_entity_billing"]) }

    it "rebinds the subscription to the new billing entity" do
      result = subject

      result_data = result["data"]["updateSubscription"]

      expect(result_data["billingEntityId"]).to eq(new_billing_entity.id)
      expect(subscription.reload.billing_entity_id).to eq(new_billing_entity.id)
    end

    context "when billing_entity_id does not exist" do
      let(:input) { {id: subscription.id, billingEntityId: SecureRandom.uuid} }

      it "returns a not_found error" do
        result = subject

        expect(result["data"]["updateSubscription"]).to be_nil
        expect(result["errors"].first["extensions"]).to include(
          "code" => "not_found",
          "details" => {"billingEntity" => ["not_found"]}
        )
      end
    end
  end
end
