# frozen_string_literal: true

module Mutations
  module Coupons
    class Terminate < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "coupons:update"

      graphql_name "TerminateCoupon"
      description "Deletes a coupon"

      argument :id, ID, required: true

      type Types::Coupons::Object

      def resolve(id:)
        coupon = current_organization.coupons.find_by(id:)
        result = ::Coupons::TerminateService.call(coupon)

        result.success? ? result.coupon : result_error(result)
      end
    end
  end
end
