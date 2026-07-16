# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::CreditNotes::EstimateResolver, :premium do
  let(:query) do
    <<~GQL
      query($invoiceId: ID!, $items: [CreditNoteItemInput!]!) {
        creditNoteEstimate(invoiceId: $invoiceId, items: $items) {
          currency
          taxesAmountCents
          subTotalExcludingTaxesAmountCents
          maxCreditableAmountCents
          maxRefundableAmountCents
          couponsAdjustmentAmountCents
          taxesRate
          items { amountCents fee { id } }
          appliedTaxes { id amountCents }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, organization:, customer:) }

  let(:fees) do
    create_list(
      :fee,
      2,
      invoice:,
      amount_cents: 100,
      precise_coupons_amount_cents: 50
    )
  end

  let(:coupon) do
    create(
      :coupon,
      organization:,
      amount_cents: 100,
      expiration: :no_expiration,
      coupon_type: :fixed_amount,
      frequency: :forever
    )
  end

  let(:applied_coupon) { create(:applied_coupon, coupon:, customer:) }

  let(:credit) { create(:credit, invoice:, applied_coupon:, amount_cents: 100) }

  before { credit }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"

  it "returns the estimate for the credit note creation" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      query:,
      variables: {
        invoiceId: invoice.id,
        items: fees.map { |f| {feeId: f.id, amountCents: 50} }
      }
    )

    estimate_response = result["data"]["creditNoteEstimate"]

    expect(estimate_response["currency"]).to eq("EUR")
    expect(estimate_response["taxesAmountCents"]).to eq("0")
    expect(estimate_response["subTotalExcludingTaxesAmountCents"]).to eq("50")
    expect(estimate_response["maxCreditableAmountCents"]).to eq("50")
    expect(estimate_response["maxRefundableAmountCents"]).to eq("0")
    expect(estimate_response["couponsAdjustmentAmountCents"]).to eq("50")
    expect(estimate_response["items"].first["amountCents"]).to eq("50")
    expect(estimate_response["appliedTaxes"]).to be_blank
  end

  context "with invalid invoice" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        query:,
        variables: {
          invoiceId: create(:invoice).id,
          items: fees.map { |f| {feeId: f.id, amountCents: 50} }
        }
      )

      expect_not_found(result)
    end
  end
end
