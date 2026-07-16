# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::CreditNotes::ResendEmail do
  let(:required_permission) { "credit_notes:send" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:, email: "customer@example.com") }
  let(:billing_entity) { customer.billing_entity }
  let(:invoice) { create(:invoice, customer:, organization:, status: :finalized) }
  let(:credit_note) { create(:credit_note, invoice:, customer:, status: :finalized) }

  let(:mutation) do
    <<~GQL
      mutation($input: ResendCreditNoteEmailInput!) {
        resendCreditNoteEmail(input: $input) {
          id
        }
      }
    GQL
  end

  before do
    billing_entity.update!(email: "billing@example.com")
    billing_entity.email_settings = ["credit_note.created"]
    billing_entity.save!
    allow(License).to receive(:premium?).and_return(true)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "credit_notes:send"

  it "resends the credit note email" do
    expect do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {input: {id: credit_note.id}}
      )

      expect(result["data"]["resendCreditNoteEmail"]["id"]).to eq(credit_note.id)
    end.to have_enqueued_mail(CreditNoteMailer, :created)
  end

  context "with custom recipients" do
    it "resends the credit note email with custom recipients" do
      expect do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query: mutation,
          variables: {
            input: {
              id: credit_note.id,
              to: ["custom@example.com"],
              cc: ["cc@example.com"],
              bcc: ["bcc@example.com"]
            }
          }
        )

        expect(result["data"]["resendCreditNoteEmail"]["id"]).to eq(credit_note.id)
      end.to have_enqueued_mail(CreditNoteMailer, :created)
    end
  end

  context "when credit note does not exist" do
    it "returns a not found error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {input: {id: SecureRandom.uuid}}
      )

      expect(result["errors"]).to be_present
      expect(result["errors"].first["extensions"]["code"]).to eq("not_found")
    end
  end
end
