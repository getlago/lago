# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Invoices::ResendEmail do
  let(:required_permission) { "invoices:send" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:, email: "customer@example.com") }
  let(:billing_entity) { customer.billing_entity }
  let(:invoice) { create(:invoice, customer:, organization:, status: :finalized) }

  let(:mutation) do
    <<~GQL
      mutation($input: ResendInvoiceEmailInput!) {
        resendInvoiceEmail(input: $input) {
          id
        }
      }
    GQL
  end

  before do
    billing_entity.update!(email: "billing@example.com")
    billing_entity.email_settings = ["invoice.finalized"]
    billing_entity.save!
    allow(License).to receive(:premium?).and_return(true)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:send"

  it "resends the invoice email" do
    expect do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {input: {id: invoice.id}}
      )

      expect(result["data"]["resendInvoiceEmail"]["id"]).to eq(invoice.id)
    end.to have_enqueued_mail(InvoiceMailer, :created)
  end

  context "with custom recipients" do
    it "resends the invoice email with custom recipients" do
      expect do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query: mutation,
          variables: {
            input: {
              id: invoice.id,
              to: ["custom@example.com"],
              cc: ["cc@example.com"],
              bcc: ["bcc@example.com"]
            }
          }
        )

        expect(result["data"]["resendInvoiceEmail"]["id"]).to eq(invoice.id)
      end.to have_enqueued_mail(InvoiceMailer, :created)
    end
  end

  context "when invoice does not exist" do
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
