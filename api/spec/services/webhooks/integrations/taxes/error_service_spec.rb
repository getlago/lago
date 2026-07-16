# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Integrations::Taxes::ErrorService do
  subject(:webhook_service) { described_class.new(object: customer, options: webhook_options) }

  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:webhook_options) do
    {
      provider_error: {message: "message", error_code: "code"}
    }
  end

  describe ".call" do
    it_behaves_like "creates webhook", "customer.tax_provider_error", "tax_provider_customer_error"
  end
end
