# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::PaymentRequestSerializer do
  subject(:serializer) do
    described_class.new(
      payment_request,
      root_name: "payment_request",
      includes: %i[customer invoices]
    )
  end

  let(:invoice) { create(:invoice) }
  let(:payment_request) { create(:payment_request, invoices: [invoice]) }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["payment_request"]).to include(
      "lago_id" => payment_request.id,
      "email" => payment_request.email,
      "amount_cents" => payment_request.amount_cents,
      "amount_currency" => payment_request.amount_currency,
      "payment_status" => payment_request.payment_status,
      "created_at" => payment_request.created_at.iso8601,
      "customer" => hash_including("lago_id" => payment_request.customer.id),
      "invoices" => [
        hash_including("lago_id" => invoice.id)
      ]
    )
  end
end
