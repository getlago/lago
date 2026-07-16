# frozen_string_literal: true

class CouponsQuery < BaseQuery
  Result = BaseResult[:coupons]
  Filters = BaseFilters[:organization_id, :status]

  def call
    coupons = base_scope.result
    coupons = paginate(coupons)
    coupons = coupons.order_by_status_and_expiration
    coupons = apply_consistent_ordering(coupons)

    coupons = with_status(coupons) if filters.status.present?

    result.coupons = coupons
    result
  end

  private

  def base_scope
    Coupon.where(organization:).ransack(search_params)
  end

  def search_params
    return if search_term.blank?

    {
      m: "or",
      name_cont: search_term,
      code_cont: search_term
    }
  end

  def with_status(scope)
    scope.where(status: filters.status)
  end
end
