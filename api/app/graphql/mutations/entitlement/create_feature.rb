# frozen_string_literal: true

module Mutations
  module Entitlement
    class CreateFeature < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "features:create"

      description "Creates a new feature"

      input_object_class Types::Entitlement::CreateFeatureInput

      type Types::Entitlement::FeatureObject

      def resolve(**args)
        result = ::Entitlement::FeatureCreateService.call(
          organization: current_organization,
          params: {
            code: args[:code],
            name: args[:name],
            description: args[:description],
            privileges: args[:privileges].map(&:to_h)
          }
        )

        result.success? ? result.feature : result_error(result)
      end
    end
  end
end
