# frozen_string_literal: true

module Api
  module V1
    class PaymentRequestsController < Api::BaseController
      include PaymentRequestIndex

      def create
        result = PaymentRequests::CreateService.call(
          organization: current_organization,
          params: create_params.to_h.deep_symbolize_keys
        )

        if result.success?
          render(
            json: ::V1::PaymentRequestSerializer.new(
              result.payment_request,
              root_name: "payment_request",
              includes: %i[customer invoices]
            )
          )
        else
          render_error_response(result)
        end
      end

      def index
        permitted_params = params.permit(:external_customer_id, :payment_status)
        external_customer_id = permitted_params[:external_customer_id]
        payment_request_index(external_customer_id: external_customer_id)
      end

      def show
        payment_request = PaymentRequest.where(organization: current_organization).find_by(id: params[:id])
        return not_found_error(resource: resource_name) unless payment_request

        render_payment_request(payment_request)
      end

      private

      def create_params
        params.require(:payment_request).permit(
          :email,
          :external_customer_id,
          lago_invoice_ids: []
        )
      end

      def render_payment_request(payment_request)
        render(
          json: ::V1::PaymentRequestSerializer.new(
            payment_request,
            root_name: resource_name,
            includes: %i[customer invoices]
          )
        )
      end

      def resource_name
        "payment_request"
      end
    end
  end
end
