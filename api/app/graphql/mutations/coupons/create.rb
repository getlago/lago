# frozen_string_literal: true

module Mutations
  module Coupons
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "coupons:create"

      graphql_name "CreateCoupon"
      description "Creates a new Coupon"

      input_object_class Types::Coupons::CreateInput

      type Types::Coupons::Object

      def resolve(**args)
        result = ::Coupons::CreateService.call(args.merge(organization_id: current_organization.id))

        result.success? ? result.coupon : result_error(result)
      end
    end
  end
end
