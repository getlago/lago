# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::PaymentProviders::InvoicePaymentSerializer do
  subject(:serializer) { described_class.new(invoice, options) }

  let(:invoice) { create(:invoice) }
  let(:options) do
    {"payment_url" => "https://example.com"}.with_indifferent_access
  end

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["data"]["lago_customer_id"]).to eq(invoice.customer.id)
    expect(result["data"]["external_customer_id"]).to eq(invoice.customer.external_id)
    expect(result["data"]["payment_provider"]).to eq(invoice.customer.payment_provider)
    expect(result["data"]["lago_invoice_id"]).to eq(invoice.id)
    expect(result["data"]["payment_url"]).to eq("https://example.com")
  end
end
