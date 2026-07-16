# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::CreditNotes::Void do
  let(:required_permission) { "credit_notes:void" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, organization:, customer:) }
  let(:credit_note) { create(:credit_note, customer:, invoice:) }

  let(:mutation) do
    <<~GQL
      mutation($input: VoidCreditNoteInput!) {
        voidCreditNote(input: $input) {
          id
          creditStatus
          canBeVoided
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "credit_notes:void"

  it "voids the credit note" do
    result = execute_query(
      query: mutation,
      input: {id: credit_note.id}
    )

    result_data = result["data"]["voidCreditNote"]

    expect(result_data["id"]).to eq(credit_note.id)
    expect(result_data["creditStatus"]).to eq("voided")
  end

  context "when credit note is not found" do
    it "returns an error" do
      result = execute_query(
        query: mutation,
        input: {id: "foo_bar"}
      )

      expect_not_found(result)
    end
  end
end
