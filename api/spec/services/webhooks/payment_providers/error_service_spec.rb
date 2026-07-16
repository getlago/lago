# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::PaymentProviders::ErrorService do
  subject(:webhook_service) { described_class.new(object: payment_provider, options: webhook_options) }

  let(:payment_provider) { create(:stripe_provider, organization:) }
  let(:organization) { create(:organization) }
  let(:webhook_options) { {provider_error: {message: "message", error_code: "code", source: "stripe", action: "payment_provider.register_webhook"}} }

  it_behaves_like "creates webhook", "payment_provider.error", "payment_provider_error"
end
