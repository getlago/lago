# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Invoices::Void do
  let(:required_permission) { "invoices:void" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, status: :finalized, customer:, organization:) }

  let(:mutation) do
    <<~GQL
      mutation($input: VoidInvoiceInput!) {
        voidInvoice(input: $input) {
          id
          status
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:void"

  it "voids the given invoice" do
    freeze_time do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {id: invoice.id}
        }
      )

      result_data = result["data"]["voidInvoice"]

      expect(result_data["id"]).to be_present
      expect(result_data["status"]).to eq("voided")
    end
  end

  context "when passing credit note parameters", :premium do
    let(:credit_amount) { 0 }
    let(:refund_amount) { 0 }

    it "calls the void service with all parameters" do
      allow(::Invoices::VoidService).to receive(:call).with(
        invoice: instance_of(Invoice),
        params: hash_including(
          generate_credit_note: true,
          credit_amount: credit_amount,
          refund_amount: refund_amount
        )
      ).and_call_original

      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: invoice.id,
            generateCreditNote: true,
            creditAmount: credit_amount,
            refundAmount: refund_amount
          }
        }
      )

      expect(::Invoices::VoidService).to have_received(:call).with(
        invoice: instance_of(Invoice),
        params: hash_including(
          generate_credit_note: true,
          credit_amount: credit_amount,
          refund_amount: refund_amount
        )
      )

      result_data = result["data"]["voidInvoice"]

      expect(result_data["id"]).to be_present
      expect(result_data["status"]).to eq("voided")
    end
  end
end
