# frozen_string_literal: true

module Mutations
  module ApiKeys
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "developers:keys:manage"

      graphql_name "UpdateApiKey"

      input_object_class Types::ApiKeys::UpdateInput

      type Types::ApiKeys::Object

      def resolve(id:, **params)
        api_key = current_organization.api_keys.find_by(id:)
        result = ::ApiKeys::UpdateService.call(api_key:, params:)
        result.success? ? result.api_key : result_error(result)
      end
    end
  end
end
