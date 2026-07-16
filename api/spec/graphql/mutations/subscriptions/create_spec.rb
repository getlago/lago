# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Subscriptions::Create, :premium do
  let(:required_permission) { "subscriptions:create" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:plan) { create(:plan, organization:) }
  let(:charge) { create(:standard_charge, plan:) }
  let(:fixed_charge) { create(:fixed_charge, plan:) }
  let(:threshold) { create(:usage_threshold, plan:) }
  let(:ending_at) { Time.current.beginning_of_day + 1.year }
  let(:customer) { create(:customer, organization:) }

  let(:feature) { create(:feature, code: :seats, organization:) }
  let(:privilege) { create(:privilege, feature:, code: "max", value_type: "integer") }
  let(:entitlement) { create(:entitlement, feature:, plan:) }
  let(:entitlement_value) { create(:entitlement_value, privilege:, entitlement:, value: "99") }

  let(:feature2) { create(:feature, code: "sso", organization:) }

  let(:mutation) do
    <<~GQL
      mutation($input: CreateSubscriptionInput!) {
        createSubscription(input: $input) {
          id
          status
          name
          externalId
          startedAt
          billingTime
          subscriptionAt
          endingAt
          progressiveBillingDisabled
          customer {
            id
          },
          plan {
            id
            amountCents
            fixedCharges {
              invoiceDisplayName
              units
            }
          }
          usageThresholds {
            amountCents
            thresholdDisplayName
          }
        }
      }
    GQL
  end

  before { organization.update!(premium_integrations: ["progressive_billing"]) }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "subscriptions:create"

  it "creates a subscription" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          customerId: customer.id,
          planId: plan.id,
          name: "name",
          externalId: "custom-external-id",
          billingTime: "anniversary",
          endingAt: ending_at.iso8601,
          progressiveBillingDisabled: true,
          usageThresholds: [
            amountCents: 100,
            thresholdDisplayName: "threshold display name"
          ],
          planOverrides: {
            amountCents: 100,
            charges: [
              id: charge.id,
              billableMetricId: charge.billable_metric_id,
              invoiceDisplayName: "invoice display name"
            ],
            fixedCharges: [
              {
                id: fixed_charge.id,
                invoiceDisplayName: "NEW fixed charge display name",
                units: "99"
              }
            ]
          }
        }
      }
    )

    result_data = result["data"]["createSubscription"]

    expect(result_data).to include(
      "id" => String,
      "status" => "active",
      "name" => "name",
      "externalId" => "custom-external-id",
      "startedAt" => String,
      "billingTime" => "anniversary",
      "endingAt" => ending_at.iso8601,
      "progressiveBillingDisabled" => true
    )
    expect(result_data["customer"]).to include(
      "id" => customer.id
    )
    expect(result_data["plan"]).to include(
      "id" => String,
      "amountCents" => "100"
    )
    expect(result_data["usageThresholds"].first).to include(
      "thresholdDisplayName" => "threshold display name",
      "amountCents" => "100"
    )
    expect(result_data["plan"]["fixedCharges"].first).to include(
      "invoiceDisplayName" => "NEW fixed charge display name",
      "units" => "99"
    )
  end

  context "with billing entity binding" do
    let(:billing_entity) { create(:billing_entity, organization:) }
    let(:mutation) do
      <<~GQL
        mutation($input: CreateSubscriptionInput!) {
          createSubscription(input: $input) {
            id
            externalId
          }
        }
      GQL
    end

    context "when multi_entity_billing flag is enabled" do
      before { organization.enable_feature_flag!(:multi_entity_billing) }

      it "binds the subscription to the resolved entity" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query: mutation,
          variables: {
            input: {
              customerId: customer.id,
              planId: plan.id,
              billingTime: "anniversary",
              billingEntityId: billing_entity.id
            }
          }
        )

        external_id = result["data"]["createSubscription"]["externalId"]
        subscription = Subscription.find_by(external_id:)
        expect(subscription.billing_entity_id).to eq(billing_entity.id)
      end

      it "returns a not_found error when billing_entity_id is unknown" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query: mutation,
          variables: {
            input: {
              customerId: customer.id,
              planId: plan.id,
              billingTime: "anniversary",
              billingEntityId: SecureRandom.uuid
            }
          }
        )

        expect(result["errors"].first["extensions"]).to include(
          "code" => "not_found",
          "details" => {"billingEntity" => ["not_found"]}
        )
      end
    end

    context "when multi_entity_billing flag is disabled" do
      it "ignores the billing entity binding" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query: mutation,
          variables: {
            input: {
              customerId: customer.id,
              planId: plan.id,
              billingTime: "anniversary",
              billingEntityId: billing_entity.id
            }
          }
        )

        external_id = result["data"]["createSubscription"]["externalId"]
        subscription = Subscription.find_by(external_id:)
        expect(subscription.billing_entity_id).to be_nil
      end
    end
  end

  context "with activation rules" do
    let(:customer) { create(:customer, organization:, payment_provider: "stripe") }

    let(:mutation) do
      <<~GQL
        mutation($input: CreateSubscriptionInput!) {
          createSubscription(input: $input) {
            id
            status
            cancellationReason
            activationRules {
              id
              type
              timeoutHours
              status
              expiresAt
              createdAt
              updatedAt
            }
          }
        }
      GQL
    end

    before { create(:payment_method, customer:, organization:) }

    it "creates a subscription with activation rules" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            customerId: customer.id,
            planId: plan.id,
            billingTime: "anniversary",
            subscriptionAt: (Time.current + 5.days).iso8601,
            activationRules: [
              {type: "payment", timeoutHours: 48}
            ]
          }
        }
      )

      result_data = result["data"]["createSubscription"]

      expect(result_data).to include(
        "status" => "pending",
        "cancellationReason" => nil
      )
      expect(result_data["activationRules"].size).to eq(1)
      expect(result_data["activationRules"].first).to include(
        "id" => String,
        "type" => "payment",
        "timeoutHours" => 48,
        "status" => "inactive",
        "createdAt" => String,
        "expiresAt" => nil,
        "updatedAt" => String
      )
    end
  end
end
