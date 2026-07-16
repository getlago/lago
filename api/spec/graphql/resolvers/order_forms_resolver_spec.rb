# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::OrderFormsResolver do
  let(:required_permission) { "order_forms:view" }
  let(:query) {}

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let!(:order_form) { create(:order_form, organization:, customer:) }

  before { create(:order_form, :signed, organization:, customer:) }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "order_forms:view"

  context "when listing all order forms" do
    let(:query) do
      <<~GQL
        query {
          orderForms(limit: 5) {
            collection {
              id
              number
              status
              quote {
                id
                number
                currentVersion { id }
              }
            }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    it "returns a list of order forms with their quotes" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      response = result["data"]["orderForms"]

      expect(response["collection"].count).to eq(2)
      expect(response["metadata"]["totalCount"]).to eq(2)

      collection = response["collection"]
      expect(collection.map { |row| row["quote"]["id"] }).to match_array(
        OrderForm.where(id: collection.map { |row| row["id"] }).map { |of| of.quote.id }
      )
      expect(collection).to all(satisfy { |row| row.dig("quote", "currentVersion", "id").present? })
    end
  end

  context "when filtering by status" do
    let(:query) do
      <<~GQL
        query($status: [OrderFormStatusEnum!]) {
          orderForms(status: $status, limit: 5) {
            collection { id status }
            metadata { totalCount }
          }
        }
      GQL
    end

    it "returns only matching order forms" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {status: ["generated"]}
      )

      response = result["data"]["orderForms"]

      expect(response["collection"].count).to eq(1)
      expect(response["collection"].first["id"]).to eq(order_form.id)
    end
  end

  context "when filtering by number" do
    let(:query) do
      <<~GQL
        query($number: [String!]) {
          orderForms(number: $number, limit: 5) {
            collection { id number }
            metadata { totalCount }
          }
        }
      GQL
    end

    it "returns only matching order forms" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {number: [order_form.number]}
      )

      response = result["data"]["orderForms"]

      expect(response["collection"].count).to eq(1)
      expect(response["collection"].first["id"]).to eq(order_form.id)
    end
  end

  context "when filtering by customer_id" do
    let(:other_customer) { create(:customer, organization:) }

    let(:query) do
      <<~GQL
        query($customerId: [ID!]) {
          orderForms(customerId: $customerId, limit: 5) {
            collection { id }
            metadata { totalCount }
          }
        }
      GQL
    end

    before { create(:order_form, organization:, customer: other_customer) }

    it "returns only matching order forms" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {customerId: [customer.id]}
      )

      response = result["data"]["orderForms"]

      expect(response["collection"].count).to eq(2)
      expect(response["metadata"]["totalCount"]).to eq(2)
    end
  end

  context "when filtering by quote_number" do
    let(:query) do
      <<~GQL
        query($quoteNumber: [String!]) {
          orderForms(quoteNumber: $quoteNumber, limit: 5) {
            collection { id }
            metadata { totalCount }
          }
        }
      GQL
    end

    it "returns only order forms linked to the specified quote" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {quoteNumber: [order_form.quote_version.quote.number]}
      )

      response = result["data"]["orderForms"]

      expect(response["collection"].count).to eq(1)
      expect(response["collection"].first["id"]).to eq(order_form.id)
    end
  end

  context "when filtering by owner_id" do
    let(:query) do
      <<~GQL
        query($ownerId: [ID!]) {
          orderForms(ownerId: $ownerId, limit: 5) {
            collection { id }
            metadata { totalCount }
          }
        }
      GQL
    end

    before do
      QuoteOwner.create!(organization:, quote: order_form.quote_version.quote, user: membership.user)
    end

    it "returns only order forms whose quote has the specified owner" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {ownerId: [membership.user.id]}
      )

      response = result["data"]["orderForms"]

      expect(response["collection"].count).to eq(1)
      expect(response["collection"].first["id"]).to eq(order_form.id)
    end
  end

  context "when filtering by created_at range" do
    let!(:order_form) { create(:order_form, organization:, customer:, created_at: 5.days.ago) }

    let(:query) do
      <<~GQL
        query($createdAtFrom: ISO8601DateTime, $createdAtTo: ISO8601DateTime) {
          orderForms(createdAtFrom: $createdAtFrom, createdAtTo: $createdAtTo, limit: 5) {
            collection { id }
            metadata { totalCount }
          }
        }
      GQL
    end

    it "returns only order forms within the date range" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {createdAtFrom: 2.days.ago.iso8601, createdAtTo: 1.day.from_now.iso8601}
      )

      response = result["data"]["orderForms"]

      expect(response["collection"].count).to eq(1)
      expect(response["metadata"]["totalCount"]).to eq(1)
    end
  end

  context "when searching by search_term" do
    let(:query) do
      <<~GQL
        query($searchTerm: String) {
          orderForms(searchTerm: $searchTerm, limit: 5) {
            collection { id number }
            metadata { totalCount }
          }
        }
      GQL
    end

    it "returns only order forms whose number matches the search term" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {searchTerm: order_form.number}
      )

      response = result["data"]["orderForms"]

      expect(response["collection"].count).to eq(1)
      expect(response["collection"].first["id"]).to eq(order_form.id)
    end
  end

  context "when filtering by expires_at range" do
    let!(:order_form) { create(:order_form, organization:, customer:, expires_at: 5.days.from_now) }

    let(:query) do
      <<~GQL
        query($expiresAtFrom: ISO8601DateTime, $expiresAtTo: ISO8601DateTime) {
          orderForms(expiresAtFrom: $expiresAtFrom, expiresAtTo: $expiresAtTo, limit: 5) {
            collection { id }
            metadata { totalCount }
          }
        }
      GQL
    end

    before { create(:order_form, :signed, organization:, customer:, expires_at: 15.days.from_now) }

    it "returns only order forms expiring within the date range" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {expiresAtFrom: 3.days.from_now.iso8601, expiresAtTo: 10.days.from_now.iso8601}
      )

      response = result["data"]["orderForms"]

      expect(response["collection"].count).to eq(1)
      expect(response["collection"].first["id"]).to eq(order_form.id)
    end
  end

  context "with N+1 query detection", :with_bullet, bullet: {n_plus_one_query: true, unused_eager_loading: false} do
    let(:query) do
      <<~GQL
        query {
          orderForms(limit: 10) {
            collection {
              id
              customer { id }
              quote { id }
            }
            metadata { totalCount }
          }
        }
      GQL
    end

    it "does not trigger N+1 queries" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "orderForms", "collection").length).to eq(2)
    end
  end
end
