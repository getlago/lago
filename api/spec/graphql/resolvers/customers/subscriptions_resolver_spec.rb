# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::Customers::SubscriptionsResolver do
  let(:required_permission) { "customers:view" }
  let(:query) do
    <<~GQL
      query($customerId: ID!) {
        customer(id: $customerId) {
          subscriptions(status: [#{status_filter}]) {
            id
            status
            startedAt
            plan {
              code
            }
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:status_filter) { nil }

  before do
    customer
  end

  it_behaves_like "requires permission", "customers:view"

  describe "when no status filter is provided" do
    let(:active_subscription) { create(:subscription, customer:, plan:, status: "active") }
    let(:terminated_subscription) { create(:subscription, customer:, plan:, status: "terminated") }
    let(:pending_subscription) { create(:subscription, customer:, plan:, status: "pending", started_at: 1.day.from_now) }
    let(:downgraded_active_subscription) { create(:subscription, customer:, plan: plan2, status: "active") }
    let(:pending_from_downgrade) { create(:subscription, customer:, plan:, status: "pending", previous_subscription: downgraded_active_subscription) }
    let(:plan2) { create(:plan, organization:, amount_cents: 1_000_000) }

    before do
      active_subscription
      terminated_subscription
      pending_subscription
      downgraded_active_subscription
      pending_from_downgrade
    end

    it "returns all subscriptions except downgraded pending ones" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {customerId: customer.id}
      )

      response = result["data"]["customer"]["subscriptions"]

      expect(response.count).to eq(4)
      expect(response.map { |s| s["id"] }).to contain_exactly(
        active_subscription.id,
        terminated_subscription.id,
        pending_subscription.id,
        downgraded_active_subscription.id
      )
    end
  end

  describe "when filtering by active status" do
    let(:status_filter) { "active" }
    let(:active_subscription) { create(:subscription, customer:, plan:, status: "active") }
    let(:terminated_subscription) { create(:subscription, customer:, plan:, status: "terminated") }
    let(:pending_subscription) { create(:subscription, customer:, plan:, status: "pending") }

    before do
      active_subscription
      terminated_subscription
      pending_subscription
    end

    it "returns only active subscriptions" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {customerId: customer.id}
      )
      response = result["data"]["customer"]["subscriptions"]

      expect(response.count).to eq(1)
      expect(response.first["id"]).to eq(active_subscription.id)
    end
  end

  describe "when filtering by pending status" do
    let(:status_filter) { "pending" }
    let(:active_subscription) { create(:subscription, customer:, plan:, status: "active") }
    let(:pending_subscription) { create(:subscription, customer:, plan:, status: "pending", started_at: 1.day.from_now) }

    before do
      active_subscription
      pending_subscription
    end

    it "returns only pending subscriptions that are starting in the future" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {customerId: customer.id}
      )
      response = result["data"]["customer"]["subscriptions"]

      expect(response.count).to eq(1)
      expect(response.first["id"]).to eq(pending_subscription.id)
    end
  end

  describe "when filtering by multiple statuses including pending" do
    let(:status_filter) { "active, pending" }
    let(:active_subscription) { create(:subscription, customer:, plan:, status: "active") }
    let(:pending_subscription) { create(:subscription, customer:, plan:, status: "pending", started_at: 1.day.from_now) }

    before do
      active_subscription
      pending_subscription
    end

    it "returns subscriptions matching the statuses and pending subscriptions starting in the future" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {customerId: customer.id}
      )
      response = result["data"]["customer"]["subscriptions"]

      expect(response.count).to eq(2)
      expect(response.map { |s| s["id"] }).to contain_exactly(
        active_subscription.id,
        pending_subscription.id
      )
    end
  end

  describe "when filtering by multiple statuses excluding pending" do
    let(:status_filter) { "active, terminated" }
    let(:active_subscription) { create(:subscription, customer:, plan:, status: "active") }
    let(:terminated_subscription) { create(:subscription, customer:, plan:, status: "terminated") }
    let(:pending_subscription) { create(:subscription, customer:, plan:, status: "pending") }

    before do
      active_subscription
      terminated_subscription
      pending_subscription
    end

    it "returns only subscriptions matching the specified statuses" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {customerId: customer.id}
      )
      response = result["data"]["customer"]["subscriptions"]

      expect(response.count).to eq(2)
      expect(response.map { |s| s["id"] }).to contain_exactly(
        active_subscription.id,
        terminated_subscription.id
      )
    end
  end
end
