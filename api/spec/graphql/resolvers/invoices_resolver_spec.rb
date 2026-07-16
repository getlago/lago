# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::InvoicesResolver do
  let(:required_permission) { "invoices:view" }
  let(:query) do
    <<~GQL
      query {
        invoices(limit: 5) {
          collection { id }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer_first) { create(:customer, organization:) }
  let(:customer_second) { create(:customer, organization:) }
  let(:invoice_first) do
    create(:invoice, customer: customer_first, payment_status: :pending, status: :finalized, organization:)
  end
  let(:invoice_second) do
    create(:invoice, customer: customer_second, payment_status: :succeeded, status: :finalized, organization:)
  end

  before do
    invoice_first
    invoice_second
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:view"

  it "returns all invoices" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    invoices_response = result["data"]["invoices"]
    returned_ids = invoices_response["collection"].map { |hash| hash["id"] }

    expect(invoices_response["collection"].count).to eq(2)
    expect(returned_ids).to include(invoice_first.id)
    expect(returned_ids).to include(invoice_second.id)

    expect(invoices_response["metadata"]["currentPage"]).to eq(1)
    expect(invoices_response["metadata"]["totalCount"]).to eq(2)
  end

  context "when filtering by succeeded payment status" do
    let(:query) do
      <<~GQL
        query {
          invoices(limit: 5, paymentStatus: [succeeded]) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    it "returns all succeeded invoices" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      invoices_response = result["data"]["invoices"]
      returned_ids = invoices_response["collection"].map { |hash| hash["id"] }

      expect(invoices_response["collection"].count).to eq(1)
      expect(returned_ids).not_to include(invoice_first.id)
      expect(returned_ids).to include(invoice_second.id)

      expect(invoices_response["metadata"]["currentPage"]).to eq(1)
      expect(invoices_response["metadata"]["totalCount"]).to eq(1)
    end
  end

  context "when filtering by draft status" do
    let(:invoice_third) { create(:invoice, customer: customer_second, status: :draft, organization:) }
    let(:query) do
      <<~GQL
        query {
          invoices(limit: 5, status: [draft]) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    before { invoice_third }

    it "returns all draft invoices" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      invoices_response = result["data"]["invoices"]

      expect(invoices_response["collection"].count).to eq(1)
      expect(invoices_response["collection"].first["id"]).to eq(invoice_third.id)

      expect(invoices_response["metadata"]["currentPage"]).to eq(1)
      expect(invoices_response["metadata"]["totalCount"]).to eq(1)
    end
  end

  context "when filtering by payment dispute lost" do
    let(:invoice_third) do
      create(
        :invoice,
        customer: customer_second,
        status: :draft,
        organization:
      )
    end

    let(:invoice_fourth) do
      create(
        :invoice,
        :dispute_lost,
        customer: customer_second,
        status: :finalized,
        organization:
      )
    end

    let(:query) do
      <<~GQL
        query {
          invoices(limit: 5, paymentDisputeLost: true) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    before do
      invoice_third
      invoice_fourth
    end

    it "returns all invoices with payment dispute lost" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      invoices_response = result["data"]["invoices"]

      expect(invoices_response["collection"].count).to eq(1)
      expect(invoices_response["collection"].first["id"]).to eq(invoice_fourth.id)

      expect(invoices_response["metadata"]["currentPage"]).to eq(1)
      expect(invoices_response["metadata"]["totalCount"]).to eq(1)
    end
  end

  context "when filtering by invoice type" do
    let(:invoice_third) do
      create(
        :invoice,
        customer: customer_second,
        invoice_type: "one_off",
        organization:
      )
    end

    let(:query) do
      <<~GQL
        query {
          invoices(limit: 5, invoiceType: [one_off]) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    before do
      invoice_third
    end

    it "returns all invoices with type one_off" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      invoices_response = result["data"]["invoices"]

      expect(invoices_response["collection"].count).to eq(1)
      expect(invoices_response["collection"].first["id"]).to eq(invoice_third.id)

      expect(invoices_response["metadata"]["currentPage"]).to eq(1)
      expect(invoices_response["metadata"]["totalCount"]).to eq(1)
    end
  end

  context "when filtering by currency" do
    let(:invoice_third) do
      create(
        :invoice,
        customer: customer_second,
        organization:,
        currency: "USD"
      )
    end

    let(:query) do
      <<~GQL
        query {
          invoices(limit: 5, currency: USD) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    before do
      invoice_third
    end

    it "returns all invoices with currency USD" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      invoices_response = result["data"]["invoices"]

      expect(invoices_response["collection"].count).to eq(1)
      expect(invoices_response["collection"].first["id"]).to eq(invoice_third.id)

      expect(invoices_response["metadata"]["currentPage"]).to eq(1)
      expect(invoices_response["metadata"]["totalCount"]).to eq(1)
    end
  end

  context "when filtering by customer external id" do
    let(:invoice_third) do
      create(
        :invoice,
        customer: customer_third,
        organization:
      )
    end

    let(:customer_third) { create(:customer, organization:, external_id: "external_id") }

    let(:query) do
      <<~GQL
        query {
          invoices(limit: 5, customerExternalId: "external_id") {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    before do
      invoice_third
    end

    it 'returns all invoices with customer external id "external_id"' do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      invoices_response = result["data"]["invoices"]

      expect(invoices_response["collection"].count).to eq(1)
      expect(invoices_response["collection"].first["id"]).to eq(invoice_third.id)

      expect(invoices_response["metadata"]["currentPage"]).to eq(1)
      expect(invoices_response["metadata"]["totalCount"]).to eq(1)
    end
  end

  context "when filtering by partially paid" do
    let(:invoice_third) do
      create(
        :invoice,
        customer: customer_first,
        organization:,
        total_amount_cents: 1000,
        total_paid_amount_cents: 10
      )
    end

    let(:query) do
      <<~GQL
        query {
          invoices(limit: 5, partiallyPaid: true) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    before do
      invoice_third
    end

    it "returns all partially paid invoices" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      invoices_response = result["data"]["invoices"]

      expect(invoices_response["collection"].count).to eq(1)
      expect(invoices_response["collection"].first["id"]).to eq(invoice_third.id)

      expect(invoices_response["metadata"]["currentPage"]).to eq(1)
      expect(invoices_response["metadata"]["totalCount"]).to eq(1)
    end
  end

  context "when filtering by positive due amount" do
    let(:invoice_third) do
      create(
        :invoice,
        customer: customer_first,
        organization:,
        total_amount_cents: 1000,
        total_paid_amount_cents: 10
      )
    end

    let(:query) do
      <<~GQL
        query {
          invoices(limit: 5, positiveDueAmount: #{positive_due_amount}) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    let(:result) do
      execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )
    end

    before do
      invoice_third
    end

    context "when the flag is set to true" do
      let(:positive_due_amount) { true }

      it "returns all invoices with due amount is greater than 0" do
        invoices_response = result["data"]["invoices"]

        expect(invoices_response["collection"].count).to eq(1)
        expect(invoices_response["collection"].first["id"]).to eq(invoice_third.id)

        expect(invoices_response["metadata"]["currentPage"]).to eq(1)
        expect(invoices_response["metadata"]["totalCount"]).to eq(1)
      end
    end

    context "when the flag is set to false" do
      let(:positive_due_amount) { false }

      it "returns all invoices with due amount is 0" do
        invoices_response = result["data"]["invoices"]

        expect(invoices_response["collection"].count).to eq(2)

        expect(invoices_response["collection"].map { it["id"] }).to contain_exactly(invoice_first.id, invoice_second.id)

        expect(invoices_response["metadata"]["currentPage"]).to eq(1)
        expect(invoices_response["metadata"]["totalCount"]).to eq(2)
      end
    end
  end

  context "when filtering by issuing date" do
    let(:invoice_third) do
      create(
        :invoice,
        customer: customer_second,
        organization:,
        issuing_date: 1.week.ago
      )
    end

    let(:query) do
      <<~GQL
        query {
          invoices(
            limit: 5,
            issuingDateFrom: "#{2.weeks.ago.to_date.iso8601}",
            issuingDateTo: "#{1.week.ago.to_date.iso8601}"
          ) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    before do
      invoice_third
    end

    it "returns all invoices issued within the from and to dates" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      invoices_response = result["data"]["invoices"]

      expect(invoices_response["collection"].count).to eq(1)
      expect(invoices_response["collection"].first["id"]).to eq(invoice_third.id)

      expect(invoices_response["metadata"]["currentPage"]).to eq(1)
      expect(invoices_response["metadata"]["totalCount"]).to eq(1)
    end
  end

  context "with both amount_from and amount_to" do
    subject(:result) do
      execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )
    end

    let(:query) do
      <<~GQL
        query {
          invoices(
            limit: 5,
            amountFrom: #{invoices.second.total_amount_cents},
            amountTo: #{invoices.fourth.total_amount_cents}
          ) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    let!(:invoices) do
      (1..5).to_a.map do |i|
        create(:invoice, total_amount_cents: i.succ * 1_000, organization:)
      end # from smallest to biggest
    end

    it "returns visible invoices total cents amount in provided range" do
      collection = result["data"]["invoices"]["collection"]

      expect(collection.pluck("id")).to match_array invoices[1..3].pluck(:id)
    end
  end

  context "when filtering by self billed" do
    let(:invoice_third) do
      create(
        :invoice,
        customer: customer_second,
        status: :draft,
        organization:
      )
    end

    let(:invoice_fourth) do
      create(
        :invoice,
        :self_billed,
        customer: customer_second,
        status: :finalized,
        organization:
      )
    end

    let(:query) do
      <<~GQL
        query {
          invoices(limit: 5, selfBilled: true) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    before do
      invoice_third
      invoice_fourth
    end

    it "returns all self billed invoices" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      invoices_response = result["data"]["invoices"]

      expect(invoices_response["collection"].count).to eq(1)
      expect(invoices_response["collection"].first["id"]).to eq(invoice_fourth.id)

      expect(invoices_response["metadata"]["currentPage"]).to eq(1)
      expect(invoices_response["metadata"]["totalCount"]).to eq(1)
    end
  end

  context "when preloading offset amounts" do
    subject do
      execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )
    end

    let(:query) do
      <<~GQL
        query {
          invoices(limit: 5) {
            collection { id totalDueAmountCents totalSettledAmountCents }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end
    let(:preloadable_invoices) { [invoice_first, invoice_second] }

    include_examples "preloads offset amounts"
  end

  context "when filters are invalid" do
    let(:query) do
      <<~GQL
        query {
          invoices(limit: 5, billingEntityIds: ["random"]) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      expect_graphql_error(result:, message: "Unprocessable Entity")
    end
  end

  context "when filtering by billing_entity_id" do
    let(:billing_entity2) { create(:billing_entity, organization:) }
    let(:invoice_third) do
      create(
        :invoice,
        customer: customer_second,
        billing_entity: billing_entity2,
        organization:
      )
    end

    let(:query) do
      <<~GQL
        query {
          invoices(limit: 5, billingEntityIds: ["#{billing_entity2.id}"]) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    before do
      invoice_third
    end

    it "returns all invoices for the specified billing entity" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )
      invoices_response = result["data"]["invoices"]

      expect(invoices_response["collection"].count).to eq(1)
      expect(invoices_response["collection"].first["id"]).to eq(invoice_third.id)

      expect(invoices_response["metadata"]["currentPage"]).to eq(1)
      expect(invoices_response["metadata"]["totalCount"]).to eq(1)
    end
  end

  context "when filtering by subscription_id" do
    let(:invoice_with_subscription_1) { create(:invoice, :subscription, organization:) }
    let(:invoice_with_subscription_2) { create(:invoice, :subscription, organization:) }

    let(:query) do
      <<~GQL
        query($subscriptionId: ID) {
          invoices(subscriptionId: $subscriptionId) {
            collection { id }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    let(:result) do
      execute_query(query:, variables: {subscriptionId: invoice_with_subscription_1.subscriptions.first.id})
    end

    before do
      invoice_with_subscription_1
      invoice_with_subscription_2
    end

    it "returns invoices for the specified subscription" do
      invoices_response = result["data"]["invoices"]

      expect(invoices_response["collection"].count).to eq(1)
      expect(invoices_response["collection"].first["id"]).to eq(invoice_with_subscription_1.id)

      expect(invoices_response["metadata"]["currentPage"]).to eq(1)
      expect(invoices_response["metadata"]["totalCount"]).to eq(1)
    end
  end

  context "when filtering by settlements" do
    let(:credit_note) { create(:credit_note, invoice: invoice_first, customer: invoice_first.customer, organization:) }

    before do
      create(
        :invoice_settlement,
        organization:,
        billing_entity: invoice_first.billing_entity,
        target_invoice: invoice_first,
        settlement_type: :credit_note,
        source_credit_note: credit_note
      )

      create(
        :invoice_settlement,
        organization:,
        billing_entity: invoice_second.billing_entity,
        target_invoice: invoice_second,
        settlement_type: :payment,
        source_payment: create(:payment)
      )
    end

    context "when settlements contains credit_note" do
      let(:query) do
        <<~GQL
          query {
            invoices(limit: 5, settlements: [credit_note]) {
              collection { id }
              metadata { currentPage, totalCount }
            }
          }
        GQL
      end

      it "returns invoices with a credit note settlement" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query:
        )

        invoices_response = result["data"]["invoices"]

        expect(invoices_response["collection"].pluck("id")).to eq([invoice_first.id])
        expect(invoices_response["metadata"]["totalCount"]).to eq(1)
      end
    end
  end

  context "with N+1 query detection on associations", bullet: {unused_eager_loading: false} do
    let(:query) do
      <<~GQL
        query {
          invoices(limit: 5) {
            collection {
              id
              status
              taxStatus
              paymentStatus
              paymentOverdue
              number
              issuingDate
              totalAmountCents
              totalDueAmountCents
              totalPaidAmountCents
              currency
              voidable
              paymentDisputeLostAt
              taxProviderVoidable
              invoiceType
              creditableAmountCents
              refundableAmountCents
              offsettableAmountCents
              associatedActiveWalletPresent
              voidedInvoiceId
              regeneratedInvoiceId
              customer {
                id
                externalId
                name
                displayName
                applicableTimezone
                paymentProvider
                hasActiveWallet
                email
                deletedAt
                __typename
              }
              errorDetails {
                errorCode
                errorDetails
                __typename
              }
              billingEntity {
                id
                name
                code
                email
                einvoicing
                emailSettings
                __typename
              }
              payments {
                createdAt
                paymentMethodId
                __typename
              }
            }
          }
        }
      GQL
    end

    it "does not trigger N+1 queries on associations" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      expect(result["data"]["invoices"]["collection"].count).to eq(2)
    end
  end
end
