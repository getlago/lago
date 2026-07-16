# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::PaymentProviders::InvoicePaymentFailureService do
  subject(:webhook_service) { described_class.new(object: invoice, options: webhook_options) }

  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, organization:) }
  let(:organization) { create(:organization) }
  let(:webhook_options) { {provider_error: {message: "message", error_code: "code"}} }

  describe ".call" do
    it_behaves_like "creates webhook", "invoice.payment_failure", "payment_provider_invoice_payment_error"
  end
end
