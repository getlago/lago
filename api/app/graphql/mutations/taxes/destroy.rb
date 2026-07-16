# frozen_string_literal: true

module Mutations
  module Taxes
    class Destroy < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      # Permissions ??
      # REQUIRED_PERMISSION = 'taxes:create'

      graphql_name "DestroyTax"
      description "Deletes a tax"

      argument :id, ID, required: true

      field :id, ID, null: true

      def resolve(id:)
        tax = current_organization.taxes.find_by(id:)
        result = ::Taxes::DestroyService.call(tax:)

        result.success? ? result.tax : result_error(result)
      end
    end
  end
end
