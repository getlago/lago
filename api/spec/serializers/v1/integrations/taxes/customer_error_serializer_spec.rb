# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::Integrations::Taxes::CustomerErrorSerializer do
  subject(:serializer) { described_class.new(customer, options) }

  let(:integration_customer) { create(:netsuite_customer) }
  let(:customer) { integration_customer.customer }
  let(:options) do
    {
      "provider_error" => {
        "error_message" => "message",
        "error_code" => "code"
      },
      "provider" => "netsuite",
      "provider_code" => integration_customer.integration.code
    }.with_indifferent_access
  end

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["data"]["lago_customer_id"]).to eq(customer.id)
    expect(result["data"]["external_customer_id"]).to eq(customer.external_id)
    expect(result["data"]["tax_provider"]).to eq(options[:provider])
    expect(result["data"]["tax_provider_code"]).to eq(integration_customer.integration.code)
    expect(result["data"]["provider_error"]).to eq(options[:provider_error])
  end
end
