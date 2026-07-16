# frozen_string_literal: true

class AppliedCouponsQuery < BaseQuery
  Result = BaseResult[:applied_coupons]
  Filters = BaseFilters[:external_customer_id, :status, :coupon_code]

  def call
    applied_coupons = paginate(base_scope)
    applied_coupons = apply_consistent_ordering(applied_coupons)

    applied_coupons = with_external_customer(applied_coupons) if filters.external_customer_id
    applied_coupons = with_coupon_code(applied_coupons) if filters.coupon_code.present?
    applied_coupons = with_status(applied_coupons) if valid_status?

    result.applied_coupons = applied_coupons
    result
  end

  def base_scope
    organization.applied_coupons
      .joins(:customer).where(customers: {deleted_at: nil})
  end

  def with_coupon_code(scope)
    scope.joins(:coupon).where(coupons: {code: filters.coupon_code})
  end

  def with_external_customer(scope)
    scope.where(customers: {external_id: filters.external_customer_id})
  end

  def with_status(scope)
    scope.where(status: filters.status)
  end

  def valid_status?
    AppliedCoupon.statuses.key?(filters.status)
  end
end
