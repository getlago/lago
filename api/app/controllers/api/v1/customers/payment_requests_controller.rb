# frozen_string_literal: true

module Api
  module V1
    module Customers
      class PaymentRequestsController < BaseController
        include PaymentRequestIndex

        def index
          payment_request_index(external_customer_id: customer.external_id)
        end

        private

        def resource_name
          "payment_request"
        end
      end
    end
  end
end
