# frozen_string_literal: true

module Mutations
  module AppliedCoupons
    class Terminate < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "coupons:detach"

      graphql_name "TerminateAppliedCoupon"
      description "Unassign a coupon from a customer"

      argument :id, ID, required: true

      type Types::AppliedCoupons::Object

      def resolve(id:)
        applied_coupon = current_organization.applied_coupons.find_by(id:)

        result = ::AppliedCoupons::TerminateService.call(applied_coupon:)

        result.success? ? result.applied_coupon : result_error(result)
      end
    end
  end
end
