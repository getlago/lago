# frozen_string_literal: true

module Api
  module V1
    module Customers
      class PaymentMethodsController < BaseController
        include PaymentMethodIndex

        def index
          payment_method_index(external_customer_id: customer.external_id)
        end

        def destroy
          result = ::PaymentMethods::DestroyService.call(
            payment_method: customer.payment_methods.find_by(id: params[:id])
          )

          if result.success?
            render_payment_method(result.payment_method)
          else
            render_error_response(result)
          end
        end

        def set_as_default
          payment_method = customer.payment_methods.find_by(id: params[:id])
          return not_found_error(resource: "payment_method") unless payment_method

          result = ::PaymentMethods::SetAsDefaultService.call(payment_method:)
          if result.success?
            render_payment_method(result.payment_method)
          else
            render_error_response(result)
          end
        end

        private

        def resource_name
          "payment_method"
        end

        def render_payment_method(payment_method)
          render(
            json: ::V1::PaymentMethodSerializer.new(
              payment_method,
              root_name: "payment_method"
            )
          )
        end
      end
    end
  end
end
