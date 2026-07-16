# frozen_string_literal: true

module Mutations
  module ApiKeys
    class Destroy < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "developers:keys:manage"

      graphql_name "DestroyApiKey"
      description "Deletes an API key"

      argument :id, ID, required: true

      type Types::ApiKeys::Object

      def resolve(id:)
        api_key = current_organization.api_keys.find_by(id:)
        result = ::ApiKeys::DestroyService.call(api_key)

        result.success? ? result.api_key : result_error(result)
      end
    end
  end
end
