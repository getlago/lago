# frozen_string_literal: true

module Mutations
  module ChargeFilters
    class Destroy < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "charges:delete"

      graphql_name "DestroyChargeFilter"
      description "Deletes a Charge Filter"

      argument :cascade_updates, Boolean, required: false
      argument :id, ID, required: true

      field :id, ID, null: true

      def resolve(id:, cascade_updates: false)
        charge_filter = current_organization.charge_filters.find_by(id:)

        result = ::ChargeFilters::DestroyService.call(
          charge_filter:,
          cascade_updates:
        )

        result.success? ? result.charge_filter : result_error(result)
      end
    end
  end
end
