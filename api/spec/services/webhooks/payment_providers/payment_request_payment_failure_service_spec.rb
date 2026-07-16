# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::PaymentProviders::PaymentRequestPaymentFailureService do
  subject(:webhook_service) { described_class.new(object: payment_request, options: webhook_options) }

  let(:payment_request) { create(:payment_request, organization:, customer:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:webhook_options) { {provider_error: {message: "message", error_code: "code"}} }

  describe ".call" do
    it_behaves_like "creates webhook", "payment_request.payment_failure", "payment_provider_payment_request_payment_error"
  end
end
