# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::PaymentProviders::ErrorSerializer do
  subject(:serializer) { described_class.new(payment_provider, options) }

  let(:payment_provider) { create(:stripe_provider) }
  let(:options) do
    {
      "provider_error" => {
        "source" => "stripe",
        "action" => "payment_provider.register_webhook",
        "error_message" => "message",
        "error_code" => nil
      }
    }.with_indifferent_access
  end

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["data"]["lago_payment_provider_id"]).to eq(payment_provider.id)
    expect(result["data"]["payment_provider_code"]).to eq(payment_provider.code)
    expect(result["data"]["payment_provider_name"]).to eq(payment_provider.name)
    expect(result["data"]["source"]).to eq("stripe")
    expect(result["data"]["action"]).to eq("payment_provider.register_webhook")
    expect(result["data"]["provider_error"]).to eq({"error_message" => "message", "error_code" => nil})
  end
end
