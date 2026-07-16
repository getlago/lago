# frozen_string_literal: true

module Api
  module V1
    class PaymentsController < Api::BaseController
      include PaymentIndex

      def create
        result = Payments::ManualCreateService.call(
          organization: current_organization,
          params: create_params.to_h.deep_symbolize_keys
        )

        if result.success?
          render(
            json: ::V1::PaymentSerializer.new(result.payment, root_name: resource_name)
          )
        else
          render_error_response(result)
        end
      end

      def index
        permitted_params = params.permit(:external_customer_id)
        customer_external_id = permitted_params[:external_customer_id]
        payment_index(customer_external_id: customer_external_id)
      end

      def show
        payment = Payment.for_organization(current_organization).find_by(id: params[:id])
        return not_found_error(resource: resource_name) unless payment

        render_payment(payment)
      end

      private

      def create_params
        params.require(:payment).permit(
          :invoice_id,
          :amount_cents,
          :reference,
          :paid_at
        )
      end

      def render_payment(payment)
        render(
          json: ::V1::PaymentSerializer.new(
            payment,
            root_name: resource_name
          )
        )
      end

      def resource_name
        "payment"
      end
    end
  end
end
