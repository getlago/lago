# frozen_string_literal: true

module Mutations
  module PricingUnits
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "pricing_units:update"

      graphql_name "UpdatePricingUnit"

      input_object_class Types::PricingUnits::UpdateInput

      type Types::PricingUnits::Object

      def resolve(id:, **params)
        pricing_unit = current_organization.pricing_units.find_by(id:)
        result = ::PricingUnits::UpdateService.call(pricing_unit:, params:)

        result.success? ? result.pricing_unit : result_error(result)
      end
    end
  end
end
