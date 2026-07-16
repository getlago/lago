# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::PaymentProviders::CustomerCreatedService do
  subject(:webhook_service) { described_class.new(object: customer) }

  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }

  describe ".call" do
    it_behaves_like "creates webhook", "customer.payment_provider_created", "customer"
  end
end
