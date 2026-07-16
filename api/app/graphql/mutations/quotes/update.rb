# frozen_string_literal: true

module Mutations
  module Quotes
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "quotes:update"

      graphql_name "UpdateQuote"
      description "Update a quote"

      input_object_class Types::Quotes::UpdateInput

      type Types::Quotes::Object

      def resolve(**args)
        quote = current_organization.quotes.find_by(id: args[:id])
        result = ::Quotes::UpdateService.call(
          quote:,
          params: args.except(:id)
        )

        result.success? ? result.quote : result_error(result)
      end
    end
  end
end
