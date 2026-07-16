# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Integrations::AccountingCustomerErrorService do
  subject(:webhook_service) { described_class.new(object: customer, options: webhook_options) }

  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:webhook_options) { {provider_error: {message: "message", error_code: "code"}} }

  describe ".call" do
    it_behaves_like "creates webhook", "customer.accounting_provider_error", "accounting_provider_customer_error"
  end
end
