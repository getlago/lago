# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::Integrations::ProviderErrorSerializer do
  subject(:serializer) { described_class.new(integration, options) }

  let(:integration) { create(:netsuite_integration) }

  let(:options) do
    {
      "provider_error" => {
        "error_message" => "message",
        "error_code" => "code"
      },
      "provider" => "netsuite",
      "provider_code" => integration.code
    }.with_indifferent_access
  end

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["data"]["lago_integration_id"]).to eq(integration.id)
    expect(result["data"]["provider"]).to eq(options[:provider])
    expect(result["data"]["provider_code"]).to eq(integration.code)
    expect(result["data"]["provider_error"]).to eq(options[:provider_error])
  end
end
