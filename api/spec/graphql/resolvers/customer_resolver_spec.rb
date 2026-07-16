# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::CustomerResolver do
  let(:required_permission) { "customers:view" }
  let(:query) do
    <<~GQL
      query($customerId: ID, $externalId: ID) {
        customer(id: $customerId, externalId: $externalId) {
          id
          externalId
          externalSalesforceId
          name
          currency
          hasCreditNotes
          creditNotesCreditsAvailableCount
          creditNotesBalanceAmountCents
          applicableTimezone
          hasOverwrittenInvoiceCustomSectionsSelection
          skipInvoiceCustomSections
          invoices {
            id
            invoiceType
            paymentStatus
            totalAmountCents
            feesAmountCents
            taxesAmountCents
            subTotalExcludingTaxesAmountCents
            subTotalIncludingTaxesAmountCents
            couponsAmountCents
            creditNotesAmountCents
          }
          subscriptions(status: [active]) { id, status }
          appliedCoupons { id amountCents amountCurrency coupon { id name } }
          appliedAddOns { id amountCents amountCurrency addOn { id name } }
          taxes { id code name }
          configurableInvoiceCustomSections { id name }
          creditNotes {
            id
            creditStatus
            reason
            totalAmountCents
            creditAmountCents
            balanceAmountCents
            refundAmountCents
            items {
              id
              amountCents
              amountCurrency
              fee { id amountCents amountCurrency itemType itemCode itemName taxesRate units eventsCount }
            }
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:billing_entity) { create(:billing_entity, organization:, timezone: "America/New_York") }
  let(:customer) do
    create(:customer, billing_entity:, organization:, currency: "EUR", skip_invoice_custom_sections: false)
  end
  let(:subscription) { create(:subscription, customer:) }
  let(:applied_add_on) { create(:applied_add_on, customer:) }
  let(:applied_tax) { create(:customer_applied_tax, customer:) }
  let(:credit_note) { create(:credit_note, customer:) }
  let(:credit_note_item) { create(:credit_note_item, credit_note:) }
  let(:invoice_custom_sections) { create_list(:invoice_custom_section, 3, organization:) }

  before do
    create_list(:invoice, 2, customer:)
    applied_add_on
    applied_tax
    subscription
    credit_note_item
    invoice_custom_sections.each do |invoice_custom_section|
      create(:billing_entity_applied_invoice_custom_section, organization:, billing_entity:, invoice_custom_section:)
    end
    create(:customer_applied_invoice_custom_section, organization:, billing_entity:, customer:, invoice_custom_section: invoice_custom_sections[0])
    create(:customer_applied_invoice_custom_section, organization:, billing_entity:, customer:, invoice_custom_section: invoice_custom_sections[1])
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "customers:view"

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
    it "returns a single customer" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {
          externalId: customer.external_id
        }
      )

      customer_response = result["data"]["customer"]
      expect(customer_response["id"]).to eq(customer.id)
      expect(customer_response["externalId"]).to eq(customer.external_id)
    end
  end

  it "returns a single customer" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {
        customerId: customer.id
      }
    )

    customer_response = result["data"]["customer"]

    expect(customer_response["id"]).to eq(customer.id)
    expect(customer_response["subscriptions"].count).to eq(1)
    expect(customer_response["invoices"].count).to eq(2)
    expect(customer_response["appliedAddOns"].count).to eq(1)
    expect(customer_response["taxes"].count).to eq(1)
    expect(customer_response["currency"]).to be_present
    expect(customer_response["externalSalesforceId"]).to be_nil
    expect(customer_response["timezone"]).to be_nil
    expect(customer_response["applicableTimezone"]).to eq("TZ_AMERICA_NEW_YORK")
    expect(customer_response["hasCreditNotes"]).to be true
    expect(customer_response["creditNotesCreditsAvailableCount"]).to eq(1)
    expect(customer_response["creditNotesBalanceAmountCents"]).to eq("120")
    expect(customer_response["hasOverwrittenInvoiceCustomSectionsSelection"]).to be true
    expect(customer_response["skipInvoiceCustomSections"]).to be false
    expect(customer_response["configurableInvoiceCustomSections"].count).to eq(2)
  end

  context "when customer has invoice_custom_sections selected on organization level" do
    before do
      customer.selected_invoice_custom_sections = []
    end

    it "returns a single customer with correct hasOverwrittenInvoiceCustomSectionsSelection value" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {
          customerId: customer.id
        }
      )

      customer_response = result["data"]["customer"]
      expect(customer_response["hasOverwrittenInvoiceCustomSectionsSelection"]).to be false
    end
  end

  context "when active and pending subscriptions are requested" do
    let(:second_subscription) { create(:subscription, :pending, customer:) }
    let(:third_subscription) { create(:subscription, :pending, customer:, previous_subscription: subscription) }

    let(:query) do
      <<~GQL
        query($customerId: ID!) {
          customer(id: $customerId) {
            id externalId name currency
            invoices { id invoiceType paymentStatus }
            subscriptions(status: [active, pending]) { id, status }
            appliedCoupons { id amountCents amountCurrency coupon { id name } }
            appliedAddOns { id amountCents amountCurrency addOn { id name } }
            taxes { id name code description }
          }
        }
      GQL
    end

    before do
      second_subscription
      third_subscription
    end

    it "returns a single customer with correct subscriptions" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {
          customerId: customer.id
        }
      )

      subscription_ids = result["data"]["customer"]["subscriptions"].map { |el| el["id"] }

      expect(subscription_ids.count).to eq(2)
      expect(subscription_ids).not_to include(third_subscription.id)
    end
  end

  context "when customer is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {
          customerId: "foo"
        }
      )

      expect_graphql_error(
        result:,
        message: "Resource not found"
      )
    end
  end
end
