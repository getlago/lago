# frozen_string_literal: true

module Resolvers
  module Entitlement
    class FeatureResolver < Resolvers::BaseResolver
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "features:view"

      description "Query a single feature"

      argument :code, String, required: false, description: "Unique code of the feature"
      argument :id, ID, required: false, description: "Unique ID of the feature"

      validates required: {one_of: [:id, :code]}

      type Types::Entitlement::FeatureObject, null: false

      def resolve(id: nil, code: nil)
        if id
          current_organization.features.find(id)
        elsif code
          current_organization.features.find_by!(code:)
        end
      rescue ActiveRecord::RecordNotFound
        not_found_error(resource: "feature")
      end
    end
  end
end
