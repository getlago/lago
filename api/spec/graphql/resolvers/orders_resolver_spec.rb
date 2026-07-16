# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::OrdersResolver do
  let(:required_permission) { "orders:view" }
  let(:query) {}

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:quote) { create(:quote, organization:, customer:) }
  let(:order_form) { create(:order_form, :signed, organization:, customer:, quote:) }
  let(:quote_two) { create(:quote, organization:, customer:) }
  let(:order_form_two) { create(:order_form, :signed, organization:, customer:, quote: quote_two) }
  let!(:order_two) { create(:order, organization:, customer:, order_form: order_form_two) }

  before { create(:order, organization:, customer:, order_form:) }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "orders:view"

  context "when listing all orders" do
    let(:query) do
      <<~GQL
        query {
          orders(limit: 5) {
            collection {
              id
              number
              status
              orderType
            }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    it "returns a list of orders" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      response = result["data"]["orders"]

      expect(response["collection"].count).to eq(2)
      expect(response["metadata"]["totalCount"]).to eq(2)
    end
  end

  context "when filtering by order type" do
    let(:quote_two) { create(:quote, organization:, customer:, order_type: :one_off) }

    let(:query) do
      <<~GQL
        query($orderType: [OrderTypeEnum!]) {
          orders(orderType: $orderType, limit: 5) {
            collection { id orderType }
            metadata { totalCount }
          }
        }
      GQL
    end

    it "returns only matching orders" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {orderType: ["one_off"]}
      )

      response = result["data"]["orders"]

      expect(response["collection"].count).to eq(1)
      expect(response["collection"].first["id"]).to eq(order_two.id)
    end
  end

  context "when filtering by status" do
    let(:query) do
      <<~GQL
        query($status: [OrderStatusEnum!]) {
          orders(status: $status, limit: 5) {
            collection { id status }
            metadata { totalCount }
          }
        }
      GQL
    end

    it "returns only matching orders" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {status: ["created"]}
      )

      response = result["data"]["orders"]

      expect(response["collection"].count).to eq(2)
      expect(response["metadata"]["totalCount"]).to eq(2)
    end
  end

  context "when filtering by execution_mode" do
    let!(:order_two) { create(:order, organization:, customer:, order_form: order_form_two, execution_mode: :order_only) }

    let(:query) do
      <<~GQL
        query($executionMode: [OrderExecutionModeEnum!]) {
          orders(executionMode: $executionMode, limit: 5) {
            collection { id }
            metadata { totalCount }
          }
        }
      GQL
    end

    it "returns only matching orders" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {executionMode: ["order_only"]}
      )

      response = result["data"]["orders"]

      expect(response["collection"].count).to eq(1)
      expect(response["collection"].first["id"]).to eq(order_two.id)
    end
  end

  context "when filtering by number" do
    let(:query) do
      <<~GQL
        query($number: [String!]) {
          orders(number: $number, limit: 5) {
            collection { id number }
            metadata { totalCount }
          }
        }
      GQL
    end

    it "returns only matching orders" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {number: [order_two.number]}
      )

      response = result["data"]["orders"]

      expect(response["collection"].count).to eq(1)
      expect(response["collection"].first["id"]).to eq(order_two.id)
    end
  end

  context "when filtering by customer_id" do
    let(:other_customer) { create(:customer, organization:) }
    let(:other_quote) { create(:quote, organization:, customer: other_customer) }
    let(:other_order_form) { create(:order_form, :signed, organization:, customer: other_customer, quote: other_quote) }

    let(:query) do
      <<~GQL
        query($customerId: [ID!]) {
          orders(customerId: $customerId, limit: 5) {
            collection { id }
            metadata { totalCount }
          }
        }
      GQL
    end

    before { create(:order, organization:, customer: other_customer, order_form: other_order_form) }

    it "returns only matching orders" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {customerId: [customer.id]}
      )

      response = result["data"]["orders"]

      expect(response["collection"].count).to eq(2)
      expect(response["metadata"]["totalCount"]).to eq(2)
    end
  end

  context "when filtering by order_form_number" do
    let(:query) do
      <<~GQL
        query($orderFormNumber: [String!]) {
          orders(orderFormNumber: $orderFormNumber, limit: 5) {
            collection { id }
            metadata { totalCount }
          }
        }
      GQL
    end

    it "returns only matching orders" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {orderFormNumber: [order_form_two.number]}
      )

      response = result["data"]["orders"]

      expect(response["collection"].count).to eq(1)
      expect(response["collection"].first["id"]).to eq(order_two.id)
    end
  end

  context "when filtering by quote_number" do
    let(:query) do
      <<~GQL
        query($quoteNumber: [String!]) {
          orders(quoteNumber: $quoteNumber, limit: 5) {
            collection { id }
            metadata { totalCount }
          }
        }
      GQL
    end

    it "returns only matching orders" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {quoteNumber: [quote_two.number]}
      )

      response = result["data"]["orders"]

      expect(response["collection"].count).to eq(1)
      expect(response["collection"].first["id"]).to eq(order_two.id)
    end
  end

  context "when filtering by owner_id" do
    let(:query) do
      <<~GQL
        query($ownerId: [ID!]) {
          orders(ownerId: $ownerId, limit: 5) {
            collection { id }
            metadata { totalCount }
          }
        }
      GQL
    end

    before { QuoteOwner.create!(organization:, quote: quote_two, user: membership.user) }

    it "returns only matching orders" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {ownerId: [membership.user.id]}
      )

      response = result["data"]["orders"]

      expect(response["collection"].count).to eq(1)
      expect(response["collection"].first["id"]).to eq(order_two.id)
    end
  end

  context "when filtering by executed_at range" do
    let!(:order_two) { create(:order, organization:, customer:, order_form: order_form_two, executed_at: 1.day.ago) }

    let(:query) do
      <<~GQL
        query($executedAtFrom: ISO8601DateTime, $executedAtTo: ISO8601DateTime) {
          orders(executedAtFrom: $executedAtFrom, executedAtTo: $executedAtTo, limit: 5) {
            collection { id }
            metadata { totalCount }
          }
        }
      GQL
    end

    it "returns only orders within the date range" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {executedAtFrom: 2.days.ago.iso8601, executedAtTo: 1.day.from_now.iso8601}
      )

      response = result["data"]["orders"]

      expect(response["collection"].count).to eq(1)
      expect(response["collection"].first["id"]).to eq(order_two.id)
    end
  end
end
