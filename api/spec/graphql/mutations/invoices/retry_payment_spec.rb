# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Invoices::RetryPayment do
  let(:required_permission) { "invoices:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:, payment_provider: "gocardless") }
  let(:gocardless_payment_provider) { create(:gocardless_provider, organization:) }
  let(:gocardless_customer) { create(:gocardless_customer, customer:) }
  let(:user) { membership.user }
  let(:invoice) do
    create(
      :invoice,
      organization:,
      customer:,
      status: "finalized",
      payment_status: "failed",
      ready_for_payment_processing: true
    )
  end
  let(:mutation) do
    <<-GQL
      mutation($input: RetryInvoicePaymentInput!) {
        retryInvoicePayment(input: $input) {
          id
          paymentStatus
        }
      }
    GQL
  end

  before do
    gocardless_payment_provider
    gocardless_customer
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:update"

  context "with valid preconditions" do
    it "returns the invoice after payment retry" do
      result = execute_graphql(
        current_organization: organization,
        current_user: user,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {id: invoice.id}
        }
      )

      data = result["data"]["retryInvoicePayment"]

      expect(data["id"]).to eq(invoice.id)
    end

    it "returns the invoice after payment retry with dedicated payment method" do
      result = execute_graphql(
        current_organization: organization,
        current_user: user,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: invoice.id,
            paymentMethod: {paymentMethodType: "manual"}
          }
        }
      )

      data = result["data"]["retryInvoicePayment"]

      expect(data["id"]).to eq(invoice.id)
    end
  end
end
