# frozen_string_literal: true

module Webhooks
  module Integrations
    class CrmCustomerErrorService < CustomerErrorService
      private

      def webhook_type
        "customer.crm_provider_error"
      end

      def object_type
        "crm_provider_customer_error"
      end
    end
  end
end
