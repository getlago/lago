# frozen_string_literal: true

module Mutations
  module Entitlement
    class DestroyFeature < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "features:delete"

      description "Destroys an existing feature"

      argument :id, ID, required: true, description: "The ID of the feature to destroy"

      type Types::Entitlement::FeatureObject

      def resolve(**args)
        feature = current_organization.features.find_by(id: args[:id])
        result = ::Entitlement::FeatureDestroyService.call(feature:)

        result.success? ? result.feature : result_error(result)
      end
    end
  end
end
