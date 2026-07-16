# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::CreditNotes::Create, :premium do
  let(:required_permission) { "credit_notes:create" }
  let(:organization) { create(:organization) }
  let(:membership) { create(:membership, organization:) }
  let(:customer) { create(:customer, organization:) }

  let(:fee1) { create(:fee, invoice:) }
  let(:fee2) { create(:charge_fee, invoice:) }

  let(:invoice) do
    create(
      :invoice,
      customer:,
      organization:,
      payment_status: "succeeded",
      currency: "EUR",
      fees_amount_cents: 100,
      taxes_amount_cents: 120,
      total_amount_cents: 120,
      total_paid_amount_cents: 110
    )
  end

  let(:mutation) do
    <<~GQL
      mutation($input: CreateCreditNoteInput!) {
        createCreditNote(input: $input) {
          id
          creditStatus
          refundStatus
          reason
          description
          currency
          totalAmountCents
          creditAmountCents
          balanceAmountCents
          refundAmountCents
          offsetAmountCents
          items {
            id
            amountCents
            amountCurrency
            fee { id }
          }
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "credit_notes:create"

  it "creates a credit note" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          reason: "duplicated_charge",
          invoiceId: invoice.id,
          description: "Duplicated charge",
          creditAmountCents: 10,
          refundAmountCents: 5,
          offsetAmountCents: 10,
          items: [
            {
              feeId: fee1.id,
              amountCents: 10
            },
            {
              feeId: fee2.id,
              amountCents: 15
            }
          ]
        }
      }
    )

    result_data = result["data"]["createCreditNote"]

    expect(result_data["id"]).to be_present
    expect(result_data["creditStatus"]).to eq("available")
    expect(result_data["refundStatus"]).to eq("pending")
    expect(result_data["reason"]).to eq("duplicated_charge")
    expect(result_data["description"]).to eq("Duplicated charge")
    expect(result_data["currency"]).to eq("EUR")
    expect(result_data["totalAmountCents"]).to eq("25")
    expect(result_data["creditAmountCents"]).to eq("10")
    expect(result_data["balanceAmountCents"]).to eq("10")
    expect(result_data["refundAmountCents"]).to eq("5")
    expect(result_data["offsetAmountCents"]).to eq("10")

    expect(result_data["items"][0]["id"]).to be_present
    expect(result_data["items"][0]["amountCents"]).to eq("10")
    expect(result_data["items"][0]["amountCurrency"]).to eq("EUR")
    expect(result_data["items"][0]["fee"]["id"]).to eq(fee1.id)

    expect(result_data["items"][1]["id"]).to be_present
    expect(result_data["items"][1]["amountCents"]).to eq("15")
    expect(result_data["items"][1]["amountCurrency"]).to eq("EUR")
    expect(result_data["items"][1]["fee"]["id"]).to eq(fee2.id)
  end

  context "when invoice is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            reason: "duplicated_charge",
            invoiceId: "foo_id",
            creditAmountCents: 10,
            refundAmountCents: 5,
            items: [
              {
                feeId: fee1.id,
                amountCents: 15
              }
            ]
          }
        }
      )

      expect_not_found(result)
    end
  end

  context "when total amount is zero" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            reason: "duplicated_charge",
            invoiceId: invoice.id,
            creditAmountCents: 0,
            refundAmountCents: 0,
            items: [
              {
                feeId: fee1.id,
                amountCents: 0
              },
              {
                feeId: fee2.id,
                amountCents: 0
              }
            ]
          }
        }
      )

      expect_unprocessable_entity(result)
    end
  end

  context "with metadata" do
    let(:mutation) do
      <<~GQL
        mutation($input: CreateCreditNoteInput!) {
          createCreditNote(input: $input) {
            id
            metadata { key value }
          }
        }
      GQL
    end

    it "creates credit note with metadata" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            reason: "duplicated_charge",
            invoiceId: invoice.id,
            creditAmountCents: 10,
            refundAmountCents: 5,
            items: [{feeId: fee1.id, amountCents: 10}, {feeId: fee2.id, amountCents: 5}],
            metadata: [{key: "foo", value: "bar"}, {key: "baz", value: "qux"}]
          }
        }
      )

      result_data = result["data"]["createCreditNote"]
      expect(result_data["metadata"]).to match_array([
        {"key" => "foo", "value" => "bar"},
        {"key" => "baz", "value" => "qux"}
      ])
    end
  end
end
