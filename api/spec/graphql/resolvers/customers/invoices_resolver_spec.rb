# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::Customers::InvoicesResolver do
  let(:required_permission) { "invoices:view" }
  let(:query) do
    <<~GQL
      query($customerId: ID!) {
        customerInvoices(customerId: $customerId) {
          collection { id }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:, organization:) }
  let(:draft_invoice) { create(:invoice, :draft, customer:, organization:) }
  let(:finalized_invoice) { create(:invoice, customer:, organization:) }

  before do
    subscription
    draft_invoice
    finalized_invoice
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:view"

  it "returns a list of invoices" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {customerId: customer.id}
    )

    invoices_response = result["data"]["customerInvoices"]

    expect(invoices_response["collection"].count).to eq(customer.invoices.count)
    expect(invoices_response["collection"].pluck("id")).to contain_exactly(draft_invoice.id, finalized_invoice.id)
    expect(invoices_response["metadata"]["currentPage"]).to eq(1)
    expect(invoices_response["metadata"]["totalCount"]).to eq(2)
  end

  context "with filter on status" do
    let(:query) do
      <<~GQL
        query($customerId: ID!, $status: [InvoiceStatusTypeEnum!]) {
          customerInvoices(customerId: $customerId, status: $status) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    it "only returns draft invoice" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {customerId: customer.id, status: ["draft"]}
      )

      invoices_response = result["data"]["customerInvoices"]

      expect(invoices_response["collection"].count).to eq(1)
      expect(invoices_response["collection"].first["id"]).to eq(draft_invoice.id)
      expect(invoices_response["metadata"]["totalCount"]).to eq(1)
    end
  end

  context "with filter on currency" do
    let(:query) do
      <<~GQL
        query($customerId: ID!, $currency: CurrencyEnum) {
          customerInvoices(customerId: $customerId, currency: $currency) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    let!(:usd_invoice) { create(:invoice, customer:, organization:, currency: "USD") }

    it "returns only invoices matching the currency" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {customerId: customer.id, currency: "USD"}
      )

      invoices_response = result["data"]["customerInvoices"]

      expect(invoices_response["collection"].pluck("id")).to contain_exactly(usd_invoice.id)
    end
  end

  context "with filter on billing_entity_ids" do
    let(:query) do
      <<~GQL
        query($customerId: ID!, $billingEntityIds: [ID!]) {
          customerInvoices(customerId: $customerId, billingEntityIds: $billingEntityIds) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    let(:other_billing_entity) { create(:billing_entity, organization:) }
    let!(:other_be_invoice) { create(:invoice, customer:, organization:, billing_entity: other_billing_entity) }

    it "returns only invoices for the specified billing entities" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {customerId: customer.id, billingEntityIds: [other_billing_entity.id]}
      )

      invoices_response = result["data"]["customerInvoices"]

      expect(invoices_response["collection"].pluck("id")).to contain_exactly(other_be_invoice.id)
    end
  end

  context "with combined currency, billing_entity_ids, and status filters" do
    let(:query) do
      <<~GQL
        query(
          $customerId: ID!,
          $currency: CurrencyEnum,
          $billingEntityIds: [ID!],
          $status: [InvoiceStatusTypeEnum!]
        ) {
          customerInvoices(
            customerId: $customerId,
            currency: $currency,
            billingEntityIds: $billingEntityIds,
            status: $status
          ) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    let(:target_billing_entity) { create(:billing_entity, organization:) }
    let!(:target_invoice) do
      create(:invoice, customer:, organization:, currency: "USD", billing_entity: target_billing_entity)
    end

    before do
      create(:invoice, customer:, organization:, currency: "EUR", billing_entity: target_billing_entity)
      create(:invoice, customer:, organization:, currency: "USD")
      create(:invoice, :draft, customer:, organization:, currency: "USD", billing_entity: target_billing_entity)
    end

    it "returns only invoices matching all filters" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {
          customerId: customer.id,
          currency: "USD",
          billingEntityIds: [target_billing_entity.id],
          status: ["finalized"]
        }
      )

      invoices_response = result["data"]["customerInvoices"]

      expect(invoices_response["collection"].pluck("id")).to contain_exactly(target_invoice.id)
    end
  end

  context "when not member of the organization" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: create(:organization),
        query:,
        variables: {customerId: customer.id}
      )

      expect_graphql_error(
        result:,
        message: "Not in organization"
      )
    end
  end

  context "when preloading offset amounts" do
    subject do
      execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {customerId: customer.id}
      )
    end

    let(:query) do
      <<~GQL
        query($customerId: ID!) {
          customerInvoices(customerId: $customerId) {
            collection { id totalDueAmountCents totalSettledAmountCents }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end
    let(:preloadable_invoices) { [draft_invoice, finalized_invoice] }

    include_examples "preloads offset amounts"
  end

  context "when query fails" do
    it "returns an error" do
      allow(InvoicesQuery).to receive(:call).and_return(
        BaseService::Result.new.tap { |r| r.validation_failure!(errors: {base: ["test_error"]}) }
      )

      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {customerId: customer.id}
      )

      expect_graphql_error(result:, message: "Unprocessable Entity")
    end
  end

  context "when customer does not exists" do
    it "returns no results" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {customerId: "123456"}
      )

      invoices_response = result["data"]["customerInvoices"]

      expect(invoices_response["collection"].count).to eq(0)
    end
  end
end
