# frozen_string_literal: true

module Api
  module V1
    class CouponsController < Api::BaseController
      def create
        result = Coupons::CreateService.call(
          input_params.merge(organization_id: current_organization.id).to_h
        )

        if result.success?
          render_coupon(result.coupon)
        else
          render_error_response(result)
        end
      end

      def update
        coupon = current_organization.coupons.find_by(code: params[:code])

        result = Coupons::UpdateService.call(
          coupon:,
          params: input_params.to_h
        )

        if result.success?
          render_coupon(result.coupon)
        else
          render_error_response(result)
        end
      end

      def destroy
        coupon = current_organization.coupons.find_by(code: params[:code])
        result = Coupons::DestroyService.call(coupon:)

        if result.success?
          render_coupon(result.coupon)
        else
          render_error_response(result)
        end
      end

      def show
        coupon = current_organization.coupons.find_by(
          code: params[:code]
        )

        return not_found_error(resource: "coupon") unless coupon

        render_coupon(coupon)
      end

      def index
        result = CouponsQuery.call(
          organization: current_organization,
          pagination: {
            page: params[:page],
            limit: params[:per_page] || PER_PAGE
          }
        )

        if result.success?
          render(
            json: ::CollectionSerializer.new(
              result.coupons,
              ::V1::CouponSerializer,
              collection_name: "coupons",
              meta: pagination_metadata(result.coupons)
            )
          )
        else
          render_error_response(result)
        end
      end

      private

      def input_params
        params.require(:coupon).permit(
          :name,
          :code,
          :description,
          :coupon_type,
          :amount_cents,
          :amount_currency,
          :percentage_rate,
          :frequency,
          :frequency_duration,
          :expiration,
          :expiration_at,
          :reusable,
          applies_to: [
            plan_codes: [],
            billable_metric_codes: []
          ]
        )
      end

      def render_coupon(coupon)
        render(
          json: ::V1::CouponSerializer.new(
            coupon,
            root_name: "coupon"
          )
        )
      end

      def resource_name
        "coupon"
      end
    end
  end
end
