# frozen_string_literal: true

module Mutations
  module WebhookEndpoints
    class Destroy < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "developers:manage"

      graphql_name "DestroyWebhookEndpoint"
      description "Deletes a webhook endpoint"

      argument :id, ID, required: true

      field :id, ID, null: true

      def resolve(id:)
        webhook_endpoint = current_organization.webhook_endpoints.find_by(id:)
        result = ::WebhookEndpoints::DestroyService.call(webhook_endpoint:)

        result.success? ? result.webhook_endpoint : result_error(result)
      end
    end
  end
end
