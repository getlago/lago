# frozen_string_literal: true

module Mutations
  module QuoteVersions
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "quotes:update"

      graphql_name "UpdateQuoteVersion"
      description "Update a quote version"

      input_object_class Types::QuoteVersions::UpdateInput

      type Types::QuoteVersions::Object

      def resolve(**args)
        quote_version = current_organization.quote_versions.find_by(id: args[:id])
        result = ::QuoteVersions::UpdateService.call(
          quote_version:,
          params: args.except(:id)
        )

        result.success? ? result.quote_version : result_error(result)
      end
    end
  end
end
