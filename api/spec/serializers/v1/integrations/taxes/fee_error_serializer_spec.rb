# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::Integrations::Taxes::FeeErrorSerializer do
  subject(:serializer) { described_class.new(integration, options) }

  let(:integration) { create(:anrok_integration) }
  let(:options) do
    {
      "provider_error" => {
        "error_message" => "message",
        "error_code" => "code"
      },
      "event_transaction_id" => "123",
      "lago_charge_id" => "456"
    }.with_indifferent_access
  end

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["data"]["tax_provider_code"]).to eq(integration.code)
    expect(result["data"]["lago_charge_id"]).to eq("456")
    expect(result["data"]["event_transaction_id"]).to eq("123")
    expect(result["data"]["provider_error"]).to eq(options[:provider_error])
  end
end
