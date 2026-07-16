# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Integrations::Taxes::FeeErrorService do
  subject(:webhook_service) { described_class.new(object: integration, options: webhook_options) }

  let(:integration) { create(:anrok_integration, organization:) }
  let(:organization) { create(:organization) }
  let(:webhook_options) do
    {
      provider_error: {message: "message", error_code: "code"},
      event_transaction_id: "123",
      lago_charge_id: "456"
    }
  end

  describe ".call" do
    it_behaves_like "creates webhook", "fee.tax_provider_error", "tax_provider_fee_error"
  end
end
