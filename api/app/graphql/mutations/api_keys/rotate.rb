# frozen_string_literal: true

module Mutations
  module ApiKeys
    class Rotate < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "developers:keys:manage"

      graphql_name "RotateApiKey"
      description "Create new ApiKey while expiring provided"

      input_object_class Types::ApiKeys::RotateInput

      type Types::ApiKeys::Object

      def resolve(id:, name: nil, expires_at: nil)
        api_key = current_organization.api_keys.find_by(id:)

        result = ::ApiKeys::RotateService.call(
          api_key:,
          params: {
            name:,
            expires_at:
          }
        )

        result.success? ? result.api_key : result_error(result)
      end
    end
  end
end
