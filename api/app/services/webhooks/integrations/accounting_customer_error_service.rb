# frozen_string_literal: true

module Webhooks
  module Integrations
    class AccountingCustomerErrorService < CustomerErrorService
      private

      def webhook_type
        "customer.accounting_provider_error"
      end

      def object_type
        "accounting_provider_customer_error"
      end
    end
  end
end
