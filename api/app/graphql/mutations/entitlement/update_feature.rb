# frozen_string_literal: true

module Mutations
  module Entitlement
    class UpdateFeature < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "features:update"

      description "Updates an existing feature"

      input_object_class Types::Entitlement::UpdateFeatureInput

      type Types::Entitlement::FeatureObject

      def resolve(**args)
        feature = current_organization.features.find_by(id: args[:id])

        result = ::Entitlement::FeatureUpdateService.call(
          feature:,
          params: {
            name: args[:name],
            description: args[:description],
            privileges: args[:privileges].map(&:to_h)
          },
          partial: false
        )

        result.success? ? result.feature : result_error(result)
      end
    end
  end
end
