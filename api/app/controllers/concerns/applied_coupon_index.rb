# frozen_string_literal: true

module AppliedCouponIndex
  include Pagination
  extend ActiveSupport::Concern

  def applied_coupon_index(external_customer_id:)
    filters = params.permit(:status, coupon_code: [])
    filters[:external_customer_id] = external_customer_id
    result = AppliedCouponsQuery.call(
      organization: current_organization,
      pagination: {
        page: params[:page],
        limit: params[:per_page] || PER_PAGE
      },
      filters: filters
    )

    if result.success?
      render(
        json: ::CollectionSerializer.new(
          result.applied_coupons.includes(:credits, :coupon, :customer),
          ::V1::AppliedCouponSerializer,
          collection_name: "applied_coupons",
          meta: pagination_metadata(result.applied_coupons),
          includes: %i[credits]
        )
      )
    else
      render_error_response(result)
    end
  end
end
