# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Cashfree::Customers::CreateService do
  let(:create_service) { described_class.new(customer:, payment_provider_id:, params:, async:) }

  let(:customer) { create(:customer) }
  let(:cashfree_provider) { create(:cashfree_provider, organization: customer.organization) }
  let(:payment_provider_id) { cashfree_provider.id }
  let(:params) { {provider_customer_id: "id", sync_with_provider: true} }
  let(:async) { true }

  describe ".call" do
    it "creates a payment_provider_customer without provider_customer_id" do
      result = create_service.call

      expect(result).to be_success
      expect(result.provider_customer).to be_present
      expect(result.provider_customer.provider_customer_id).to be_nil
    end
  end
end
