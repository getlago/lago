# frozen_string_literal: true

module Mutations
  module Taxes
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      # Permissions ??
      # REQUIRED_PERMISSION = 'taxes:create'

      graphql_name "UpdateTax"
      description "Update an existing tax"

      input_object_class Types::Taxes::UpdateInput
      type Types::Taxes::Object

      def resolve(**args)
        tax = current_organization.taxes.find_by(id: args[:id])
        result = ::Taxes::UpdateService.call(tax:, params: args)

        result.success? ? result.tax : result_error(result)
      end
    end
  end
end
