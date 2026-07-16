# frozen_string_literal: true

module Mutations
  module Charges
    class Destroy < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "charges:delete"

      graphql_name "DestroyCharge"
      description "Deletes a Charge"

      argument :cascade_updates, Boolean, required: false
      argument :id, ID, required: true

      field :id, ID, null: true

      def resolve(id:, cascade_updates: false)
        charge = current_organization.charges.parents.find_by(id:)

        result = ::Charges::DestroyService.call(charge:, cascade_updates:)

        result.success? ? result.charge : result_error(result)
      end
    end
  end
end
