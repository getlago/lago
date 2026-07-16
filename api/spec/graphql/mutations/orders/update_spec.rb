# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Orders::Update do
  let(:required_permission) { "orders:update" }
  let(:organization) { create(:organization, feature_flags: ["order_forms"]) }
  let(:membership) { create(:membership, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:order) { create(:order, organization:, customer:) }

  let(:mutation) do
    <<~GQL
      mutation($input: UpdateOrderInput!) {
        updateOrder(input: $input) {
          id
          status
          executionMode
          executeAt
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "orders:update"

  it "updates the order execution settings", :premium do
    execute_at = 1.month.from_now.iso8601

    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {input: {id: order.id, executionMode: "execute_in_lago", executeAt: execute_at}}
    )

    data = result["data"]["updateOrder"]

    expect(data["id"]).to eq(order.id)
    expect(data["executionMode"]).to eq("execute_in_lago")
    expect(data["executeAt"]).to eq(Time.zone.parse(execute_at).iso8601)
  end

  it "updates only the provided field and leaves the others untouched", :premium do
    order.update!(execution_mode: "execute_in_lago", execute_at: 1.month.from_now)
    persisted_execute_at = order.reload.execute_at

    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {input: {id: order.id, executionMode: "order_only"}}
    )

    data = result["data"]["updateOrder"]

    expect(data["executionMode"]).to eq("order_only")
    expect(data["executeAt"]).to eq(persisted_execute_at.iso8601)
  end

  it "returns an error when execute_at is set without execution_mode", :premium do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {input: {id: order.id, executeAt: 1.month.from_now.iso8601}}
    )

    expect_unprocessable_entity(result, details: {executionMode: ["value_is_mandatory"]})
  end

  it "returns an error when execute_at is in the past", :premium do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {input: {id: order.id, executionMode: "execute_in_lago", executeAt: 1.day.ago.iso8601}}
    )

    expect_unprocessable_entity(result, details: {executeAt: ["invalid_date"]})
  end

  context "when the order is already executed", :premium do
    let(:order) { create(:order, :executed_in_lago, organization:, customer:) }

    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {input: {id: order.id, executionMode: "order_only"}}
      )

      expect_graphql_error(result:, message: "Unprocessable Entity", details: {status: ["not_editable"]})
    end
  end

  context "when the order is not found", :premium do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {input: {id: SecureRandom.uuid, executionMode: "order_only"}}
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
