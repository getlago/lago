# frozen_string_literal: true

module Api
  module V1
    module Customers
      class InvoicesController < BaseController
        include InvoiceIndex

        def index
          invoice_index(customer_external_id: customer.external_id)
        end

        private

        def resource_name
          "invoice"
        end
      end
    end
  end
end
