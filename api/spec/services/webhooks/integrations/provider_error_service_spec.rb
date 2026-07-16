# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Integrations::ProviderErrorService do
  subject(:webhook_service) { described_class.new(object: integration, options: webhook_options) }

  let(:integration) { create(:netsuite_integration, organization:) }
  let(:organization) { create(:organization) }
  let(:webhook_options) { {provider_error: {message: "message", error_code: "code"}} }

  describe ".call" do
    it_behaves_like "creates webhook", "integration.provider_error", "provider_error"
  end
end
