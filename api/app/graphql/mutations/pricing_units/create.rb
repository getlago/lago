# frozen_string_literal: true

module Mutations
  module PricingUnits
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "pricing_units:create"

      graphql_name "CreatePricingUnit"
      description "Creates a new pricing unit"

      input_object_class Types::PricingUnits::CreateInput

      type Types::PricingUnits::Object

      def resolve(**args)
        result = ::PricingUnits::CreateService.call(args.merge(organization: current_organization))

        result.success? ? result.pricing_unit : result_error(result)
      end
    end
  end
end
