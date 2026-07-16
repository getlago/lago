# frozen_string_literal: true

module Mutations
  module QuoteVersions
    class Approve < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "quotes:approve"

      graphql_name "ApproveQuoteVersion"
      description "Approve a quote version"

      argument :expires_at, GraphQL::Types::ISO8601DateTime, required: false
      argument :id, ID, required: true

      type Types::QuoteVersions::Object

      def resolve(**args)
        quote_version = current_organization.quote_versions.find_by(id: args[:id])
        result = ::QuoteVersions::ApproveService.call(quote_version:, expires_at: args[:expires_at])

        result.success? ? result.quote_version : result_error(result)
      end
    end
  end
end
