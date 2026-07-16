# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::PaymentProviders::CustomerCheckoutService do
  subject(:webhook_service) { described_class.new(object: customer) }

  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }

  describe ".call" do
    it_behaves_like "creates webhook", "customer.checkout_url_generated", "payment_provider_customer_checkout_url"
  end
end
