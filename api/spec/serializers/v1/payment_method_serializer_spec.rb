# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::PaymentMethodSerializer do
  subject(:serializer) do
    described_class.new(
      payment_method,
      root_name: "payment_method"
    )
  end

  let(:payment_method) { create(:payment_method) }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["payment_method"]).to include(
      "lago_id" => payment_method.id,
      "is_default" => payment_method.is_default,
      "payment_provider_code" => payment_method.payment_provider&.code,
      "payment_provider_name" => payment_method.payment_provider&.name,
      "payment_provider_type" => "stripe",
      "provider_method_id" => payment_method.provider_method_id,
      "created_at" => payment_method.created_at.iso8601
    )
  end
end
