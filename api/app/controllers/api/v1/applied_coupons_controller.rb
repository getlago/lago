# frozen_string_literal: true

module Api
  module V1
    class AppliedCouponsController < Api::BaseController
      include AppliedCouponIndex

      def create
        customer = Customer.find_by(
          external_id: create_params[:external_customer_id],
          organization_id: current_organization.id
        )

        coupon = Coupon.find_by(
          code: create_params[:coupon_code],
          organization_id: current_organization.id
        )

        result = AppliedCoupons::CreateService.call(customer:, coupon:, params: create_params)

        if result.success?
          render(
            json: ::V1::AppliedCouponSerializer.new(
              result.applied_coupon,
              root_name: "applied_coupon"
            )
          )
        else
          render_error_response(result)
        end
      end

      def index
        external_customer_id = params.permit(:external_customer_id).fetch(:external_customer_id, nil)
        applied_coupon_index(external_customer_id: external_customer_id)
      end

      private

      def create_params
        params.require(:applied_coupon).permit(
          :external_customer_id,
          :coupon_code,
          :frequency,
          :frequency_duration,
          :amount_cents,
          :amount_currency,
          :percentage_rate
        )
      end

      def resource_name
        "applied_coupon"
      end
    end
  end
end
