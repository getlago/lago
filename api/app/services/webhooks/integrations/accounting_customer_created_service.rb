# frozen_string_literal: true

module Webhooks
  module Integrations
    class AccountingCustomerCreatedService < CustomerCreatedService
      private

      def webhook_type
        "customer.accounting_provider_created"
      end
    end
  end
end
