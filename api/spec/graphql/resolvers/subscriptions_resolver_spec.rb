# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::SubscriptionsResolver do
  let(:required_permission) { "subscriptions:view" }
  let(:query) do
    <<~GQL
      query {
        subscriptions(limit: 5, planCode: "#{plan.code}", status: [active]) {
          collection { id externalId plan { code } }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:plan) { create(:plan, organization:) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }

  before do
    customer
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "subscriptions:view"

  it "returns a list of subscriptions" do
    first_subscription = create(:subscription, customer:, plan:)
    second_subscription = create(:subscription, customer:, plan:)
    create(:subscription, customer:, plan:, status: :terminated)
    create(:subscription, customer:)

    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )
    response = result["data"]["subscriptions"]

    expect(response["collection"].count).to eq(2)
    expect(response["collection"].map { |s| s["id"] }).to contain_exactly(
      first_subscription.id,
      second_subscription.id
    )
    expect(response["collection"].first["plan"]).to include(
      "code" => plan.code
    )

    expect(response["metadata"]["currentPage"]).to eq(1)
    expect(response["metadata"]["totalCount"]).to eq(2)
  end

  context "with billing_entity_ids filter" do
    let(:billing_entity_eu) { create(:billing_entity, organization:, code: "EU") }
    let(:billing_entity_us) { create(:billing_entity, organization:, code: "US") }
    let!(:eu_subscription) { create(:subscription, customer:, plan:, billing_entity: billing_entity_eu) }
    let!(:us_subscription) { create(:subscription, customer:, plan:, billing_entity: billing_entity_us) }

    let(:query) do
      <<~GQL
        query {
          subscriptions(limit: 5, billingEntityIds: ["#{billing_entity_eu.id}"]) {
            collection { id }
            metadata { totalCount }
          }
        }
      GQL
    end

    it "returns only subscriptions for the specified billing entity" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )
      response = result["data"]["subscriptions"]

      expect(response["collection"].map { |s| s["id"] }).to contain_exactly(eu_subscription.id)
      expect(response["metadata"]["totalCount"]).to eq(1)
    end

    context "with multiple billing_entity_ids" do
      let(:query) do
        <<~GQL
          query {
            subscriptions(limit: 5, billingEntityIds: ["#{billing_entity_eu.id}", "#{billing_entity_us.id}"]) {
              collection { id }
              metadata { totalCount }
            }
          }
        GQL
      end

      it "returns subscriptions matching any of the provided ids" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query:
        )
        response = result["data"]["subscriptions"]

        expect(response["collection"].map { |s| s["id"] }).to contain_exactly(
          eu_subscription.id,
          us_subscription.id
        )
        expect(response["metadata"]["totalCount"]).to eq(2)
      end
    end
  end

  context "with external_id filter" do
    let(:subscription) { create(:subscription, customer:, plan:) }

    let(:query) do
      <<~GQL
        query {
          subscriptions(limit: 5, externalId: "#{subscription.external_id}") {
            collection { id }
            metadata { totalCount }
          }
        }
      GQL
    end

    it "returns only the subscription with matching external_id" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )
      response = result["data"]["subscriptions"]

      expect(response["collection"].count).to eq(1)
      expect(response["collection"].first["id"]).to eq(subscription.id)
      expect(response["metadata"]["totalCount"]).to eq(1)
    end
  end

  context "with currency filter" do
    let(:brl_plan) { create(:plan, organization:, amount_currency: "BRL") }
    let!(:brl_subscription) { create(:subscription, customer:, plan: brl_plan) }

    let(:query) do
      <<~GQL
        query {
          subscriptions(limit: 5, currency: "#{brl_plan.amount_currency}") {
            collection { id }
            metadata { totalCount }
          }
        }
      GQL
    end

    it "returns only subscriptions with matching currency" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )
      response = result["data"]["subscriptions"]

      expect(response["collection"].count).to eq(1)
      expect(response["collection"].first["id"]).to eq(brl_subscription.id)
      expect(response["metadata"]["totalCount"]).to eq(1)
    end
  end

  context "with N+1 query detection on associations", bullet: {unused_eager_loading: false} do
    let(:query) do
      <<~GQL
        query {
          subscriptions(limit: 5, planCode: "#{plan.code}", status: [active]) {
            collection { 
              id
              status
              startedAt
              nextSubscriptionAt
              nextSubscriptionType
              name
              nextName
              externalId
              subscriptionAt
              endingAt
              terminatedAt
              customer {
                id
                name
                displayName
                applicableTimezone
              }
              plan {
                id
                isOverridden
                payInAdvance
                amountCurrency
                name
                interval
              }
              nextPlan {
                id
                name
                code
                interval
              }
              nextSubscription {
                id
                name
                externalId
                status
              }
            }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    before do
      create(:subscription, customer:, plan:)
      create(:subscription, customer:, plan:)
    end

    it "does not trigger N+1 queries on associations" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      expect(result["data"]["subscriptions"]["collection"].count).to eq(2)
    end
  end
end
