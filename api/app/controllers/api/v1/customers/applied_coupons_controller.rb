# frozen_string_literal: true

module Api
  module V1
    module Customers
      class AppliedCouponsController < BaseController
        include AppliedCouponIndex

        def index
          applied_coupon_index(external_customer_id: customer.external_id)
        end

        def destroy
          applied_coupon = customer.applied_coupons.find_by(id: params[:id])
          return not_found_error(resource: "applied_coupon") unless applied_coupon

          result = ::AppliedCoupons::TerminateService.call(applied_coupon:)
          if result.success?
            render(json: ::V1::AppliedCouponSerializer.new(result.applied_coupon, root_name: "applied_coupon"))
          else
            render_error_response(result)
          end
        end

        private

        def resource_name
          "applied_coupon"
        end
      end
    end
  end
end
