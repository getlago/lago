# frozen_string_literal: true

module Mutations
  module WebhookEndpoints
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "developers:manage"

      graphql_name "UpdateWebhookEndpoint"
      description "Update a new webhook endpoint"

      input_object_class Types::WebhookEndpoints::UpdateInput

      type Types::WebhookEndpoints::Object

      def resolve(**args)
        result = ::WebhookEndpoints::UpdateService.call(
          id: args[:id],
          organization: current_organization,
          params: args
        )

        result.success? ? result.webhook_endpoint : result_error(result)
      end
    end
  end
end
