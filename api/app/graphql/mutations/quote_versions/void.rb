# frozen_string_literal: true

module Mutations
  module QuoteVersions
    class Void < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "quotes:void"

      graphql_name "VoidQuoteVersion"
      description "Void a quote version"

      argument :id, ID, required: true

      type Types::QuoteVersions::Object

      def resolve(**args)
        quote_version = current_organization.quote_versions.find_by(id: args[:id])
        result = ::QuoteVersions::VoidService.call(
          quote_version:,
          reason: :manual
        )

        result.success? ? result.quote_version : result_error(result)
      end
    end
  end
end
