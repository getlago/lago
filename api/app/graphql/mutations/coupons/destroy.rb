# frozen_string_literal: true

module Mutations
  module Coupons
    class Destroy < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "coupons:delete"

      graphql_name "DestroyCoupon"
      description "Deletes a coupon"

      argument :id, ID, required: true

      field :id, ID, null: true

      def resolve(id:)
        coupon = current_organization.coupons.find_by(id:)
        result = ::Coupons::DestroyService.call(coupon:)

        result.success? ? result.coupon : result_error(result)
      end
    end
  end
end
