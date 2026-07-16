# frozen_string_literal: true

module Mutations
  module QuoteVersions
    class Clone < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "quotes:clone"

      graphql_name "CloneQuoteVersion"
      description "Clone a quote version"

      argument :id, ID, required: true

      type Types::QuoteVersions::Object

      def resolve(**args)
        quote_version = current_organization.quote_versions.find_by(id: args[:id])
        result = ::QuoteVersions::CloneService.call(quote_version:)

        result.success? ? result.quote_version : result_error(result)
      end
    end
  end
end
