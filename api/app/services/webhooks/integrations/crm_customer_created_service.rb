# frozen_string_literal: true

module Webhooks
  module Integrations
    class CrmCustomerCreatedService < CustomerCreatedService
      private

      def webhook_type
        "customer.crm_provider_created"
      end
    end
  end
end
