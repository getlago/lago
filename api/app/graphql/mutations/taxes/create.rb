# frozen_string_literal: true

module Mutations
  module Taxes
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      # Permissions ??
      # REQUIRED_PERMISSION = 'taxes:create'

      graphql_name "CreateTax"
      description "Creates a tax"

      input_object_class Types::Taxes::CreateInput
      type Types::Taxes::Object

      def resolve(**args)
        result = ::Taxes::CreateService.call(organization: current_organization, params: args)
        result.success? ? result.tax : result_error(result)
      end
    end
  end
end
