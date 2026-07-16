# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::PaymentProviders::PaymentRequestPaymentErrorSerializer do
  subject(:serializer) { described_class.new(payment_request, options) }

  let(:payment_request) { create(:payment_request, organization:, customer:, invoices: [invoice]) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:options) do
    {
      "provider_customer_id" => "customer",
      "provider_error" => {
        "error_message" => "message",
        "error_code" => "code"
      }
    }.with_indifferent_access
  end

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["data"]["lago_payment_request_id"]).to eq(payment_request.id)
    expect(result["data"]["lago_invoice_ids"]).to eq([invoice.id])
    expect(result["data"]["lago_customer_id"]).to eq(customer.id)
    expect(result["data"]["external_customer_id"]).to eq(customer.external_id)
    expect(result["data"]["provider_customer_id"]).to eq(options[:provider_customer_id])
    expect(result["data"]["payment_provider"]).to eq(customer.payment_provider)
    expect(result["data"]["payment_provider_code"]).to eq(customer.payment_provider_code)
    expect(result["data"]["provider_error"]).to eq(options[:provider_error])
  end
end
