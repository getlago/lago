# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Invoices::GeneratePaymentUrl do
  let(:required_permission) { "invoices:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:) }

  let(:mutation) do
    <<~GQL
      mutation($input: GeneratePaymentUrlInput!) {
        generatePaymentUrl(input: $input) {
          paymentUrl
        }
      }
    GQL
  end

  let(:service_result) do
    result = BaseService::Result.new
    result.payment_url = "https://payment.example.com/pay/123"
    result
  end

  before do
    allow(Invoices::Payments::GeneratePaymentUrlService).to receive(:call).and_return(service_result)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:update"

  it "generates a payment URL for the invoice" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          invoiceId: invoice.id
        }
      }
    )

    result_data = result["data"]["generatePaymentUrl"]

    expect(result_data["paymentUrl"]).to eq("https://payment.example.com/pay/123")
    expect(Invoices::Payments::GeneratePaymentUrlService).to have_received(:call).with(invoice:)
  end

  context "when the invoice is not found" do
    it "returns a GraphQL error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            invoiceId: "invalid"
          }
        }
      )

      expect_not_found(result)
    end
  end

  context "when service returns an error" do
    let(:service_result) do
      result = BaseService::Result.new
      result.single_validation_failure!(error_code: "no_linked_payment_provider")
      result
    end

    it "returns a GraphQL error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            invoiceId: invoice.id
          }
        }
      )

      expect_graphql_error(
        result:,
        message: "Unprocessable Entity"
      )
    end

    context "when error is ThirdPartyFailure" do
      let(:service_result) do
        result = BaseService::Result.new
        result.third_party_failure!(third_party: "stripe", error_code: 500, error_message: "Hummm, there's an error!")
        result
      end

      it "returns a GraphQL error" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query: mutation,
          variables: {
            input: {
              invoiceId: invoice.id
            }
          }
        )

        expect_graphql_error(
          result:,
          message: "Unprocessable Entity"
        )
      end
    end
  end
end
