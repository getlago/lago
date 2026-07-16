# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::PaymentReceipts::ResendEmail do
  let(:required_permission) { "payment_receipts:send" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:, email: "customer@example.com") }
  let(:billing_entity) { customer.billing_entity }
  let(:invoice) { create(:invoice, customer:, organization:, status: :finalized) }
  let(:payment) { create(:payment, payable: invoice) }
  let(:payment_receipt) { create(:payment_receipt, payment:, organization:) }

  let(:mutation) do
    <<~GQL
      mutation($input: ResendPaymentReceiptEmailInput!) {
        resendPaymentReceiptEmail(input: $input) {
          id
        }
      }
    GQL
  end

  before do
    billing_entity.update!(email: "billing@example.com")
    billing_entity.email_settings = ["payment_receipt.created"]
    billing_entity.save!
    allow(License).to receive(:premium?).and_return(true)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "payment_receipts:send"

  it "resends the payment receipt email" do
    expect do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {input: {id: payment_receipt.id}}
      )

      expect(result["data"]["resendPaymentReceiptEmail"]["id"]).to eq(payment_receipt.id)
    end.to have_enqueued_mail(PaymentReceiptMailer, :created)
  end

  context "with custom recipients" do
    it "resends the payment receipt email with custom recipients" do
      expect do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query: mutation,
          variables: {
            input: {
              id: payment_receipt.id,
              to: ["custom@example.com"],
              cc: ["cc@example.com"],
              bcc: ["bcc@example.com"]
            }
          }
        )

        expect(result["data"]["resendPaymentReceiptEmail"]["id"]).to eq(payment_receipt.id)
      end.to have_enqueued_mail(PaymentReceiptMailer, :created)
    end
  end

  context "when payment receipt does not exist" do
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
