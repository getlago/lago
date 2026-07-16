# frozen_string_literal: true

module Customers
  module PaymentProviderFinder
    extend ActiveSupport::Concern

    included do
      def payment_provider(customer)
        payment_provider_result = PaymentProviders::FindService.new(
          organization_id: customer.organization_id,
          code: customer.payment_provider_code,
          payment_provider_type: customer.payment_provider
        ).call

        return nil if payment_provider_result.error&.code == "payment_provider_not_found"

        payment_provider_result.raise_if_error!
        payment_provider_result.payment_provider
      end

      def payment_provider_customer(customer)
        return nil unless customer

        PaymentProviderCustomers::BaseCustomer.with_discarded.find_by(customer_id: customer.id)
      end
    end
  end
end
