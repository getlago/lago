# frozen_string_literal: true

module Mutations
  module Webhooks
    class Retry < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "developers:manage"

      graphql_name "RetryWebhook"
      description "Retry a Webhook"

      argument :id, ID, required: true

      type Types::Webhooks::Object

      def resolve(id:)
        webhook = current_organization.webhooks.find_by(id:)
        result = ::Webhooks::RetryService.call(webhook:)

        result.success? ? result.webhook : result_error(result)
      end
    end
  end
end
