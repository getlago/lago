# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::CreditNotes::Update do
  let(:required_permission) { "credit_notes:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, organization:, customer:) }
  let(:credit_note) { create(:credit_note, customer:, invoice:) }

  let(:mutation) do
    <<~GQL
      mutation($input: UpdateCreditNoteInput!) {
        updateCreditNote(input: $input) {
          id
          refundStatus
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "credit_notes:update"

  it "updates the credit note" do
    result = execute_query(
      query: mutation,
      input: {
        id: credit_note.id,
        refundStatus: "succeeded"
      }
    )

    result_data = result["data"]["updateCreditNote"]

    expect(result_data["id"]).to eq(credit_note.id)
    expect(result_data["refundStatus"]).to eq("succeeded")
  end

  context "when credit note is not found" do
    it "returns an error" do
      result = execute_query(
        query: mutation,
        input: {
          id: "foo_bar",
          refundStatus: "succeeded"
        }
      )

      expect_not_found(result)
    end
  end

  context "with metadata" do
    let(:mutation) do
      <<~GQL
        mutation($input: UpdateCreditNoteInput!) {
          updateCreditNote(input: $input) {
            id
            metadata { key value }
          }
        }
      GQL
    end

    before { create(:item_metadata, owner: credit_note, organization:, value: {"existing" => "value"}) }

    it "replaces metadata (not merges)" do
      result = execute_query(
        query: mutation,
        input: {
          id: credit_note.id,
          metadata: [{key: "new", value: "data"}]
        }
      )

      result_data = result["data"]["updateCreditNote"]
      expect(result_data["metadata"]).to eq([{"key" => "new", "value" => "data"}])
    end

    it "keeps the existing metadata when only the refund status is updated" do
      execute_query(
        query: mutation,
        input: {
          id: credit_note.id,
          refundStatus: "succeeded"
        }
      )

      expect(credit_note.reload.metadata.value).to eq({"existing" => "value"})
    end
  end
end
