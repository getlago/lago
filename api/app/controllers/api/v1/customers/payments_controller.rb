# frozen_string_literal: true

module Api
  module V1
    module Customers
      class PaymentsController < BaseController
        include PaymentIndex

        def index
          payment_index(customer_external_id: customer.external_id)
        end

        private

        def resource_name
          "payment"
        end
      end
    end
  end
end
