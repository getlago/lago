# frozen_string_literal: true

module Mutations
  module Coupons
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "coupons:update"

      graphql_name "UpdateCoupon"
      description "Update an existing coupon"

      input_object_class Types::Coupons::UpdateInput

      type Types::Coupons::Object

      def resolve(**args)
        coupon = current_organization.coupons.find_by(id: args[:id])
        result = ::Coupons::UpdateService.call(coupon:, params: args)
        result.success? ? result.coupon : result_error(result)
      end
    end
  end
end
