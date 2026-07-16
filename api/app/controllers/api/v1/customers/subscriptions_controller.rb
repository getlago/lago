# frozen_string_literal: true

module Api
  module V1
    module Customers
      class SubscriptionsController < BaseController
        include SubscriptionIndex

        def index
          subscription_index(external_customer_id: customer.external_id)
        end

        private

        def resource_name
          "subscription"
        end
      end
    end
  end
end
