# frozen_string_literal: true

module Api
  module V1
    class PaymentReceiptsController < Api::BaseController
      def index
        result = PaymentReceiptsQuery.call(
          organization: current_organization,
          pagination: {
            page: params[:page],
            limit: params[:per_page] || PER_PAGE
          },
          filters: index_filters
        )

        if result.success?
          render(
            json: ::CollectionSerializer.new(
              result.payment_receipts,
              ::V1::PaymentReceiptSerializer,
              collection_name: serialized_resource_name.pluralize,
              meta: pagination_metadata(result.payment_receipts)
            )
          )
        else
          render_error_response(result)
        end
      end

      def show
        payment_receipt = PaymentReceipt.where(organization: current_organization).find_by(id: params[:id])
        return not_found_error(resource: resource_name) unless payment_receipt

        render_payment_receipt(payment_receipt)
      end

      def resend_email
        payment_receipt = PaymentReceipt.where(organization: current_organization).find_by(id: params[:id])
        return not_found_error(resource: resource_name) unless payment_receipt

        result = Emails::ResendService.call(
          resource: payment_receipt,
          to: resend_email_params[:to],
          cc: resend_email_params[:cc],
          bcc: resend_email_params[:bcc]
        )

        if result.success?
          head(:ok)
        else
          render_error_response(result)
        end
      end

      private

      def index_filters
        params.permit(:invoice_id)
      end

      def resend_email_params
        params.permit(to: [], cc: [], bcc: [])
      end

      def render_payment_receipt(payment_receipt)
        render(
          json: ::V1::PaymentReceiptSerializer.new(
            payment_receipt,
            root_name: serialized_resource_name
          )
        )
      end

      def resource_name
        "invoice"
      end

      def serialized_resource_name
        "payment_receipt"
      end
    end
  end
end
