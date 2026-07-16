# frozen_string_literal: true

module Mutations
  module FixedCharges
    class Destroy < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "charges:delete"

      graphql_name "DestroyFixedCharge"
      description "Deletes a Fixed Charge"

      argument :cascade_updates, Boolean, required: false
      argument :id, ID, required: true

      field :id, ID, null: true

      def resolve(id:, cascade_updates: false)
        fixed_charge = current_organization.fixed_charges.parents.find_by(id:)

        result = ::FixedCharges::DestroyService.call(fixed_charge:, cascade_updates:)

        result.success? ? result.fixed_charge : result_error(result)
      end
    end
  end
end
