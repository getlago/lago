# frozen_string_literal: true

module Mutations
  module ChargeFilters
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "charges:update"

      graphql_name "UpdateChargeFilter"
      description "Updates an existing Charge Filter"

      input_object_class Types::ChargeFilters::UpdateInput
      type Types::ChargeFilters::Object

      def resolve(**args)
        charge_filter = current_organization.charge_filters.find_by(id: args[:id])

        params = args.except(:id, :cascade_updates).to_h.deep_symbolize_keys
        params[:properties] = params[:properties].to_h if params[:properties]

        result = ::ChargeFilters::UpdateService.call(
          charge_filter:,
          params:,
          cascade_updates: args[:cascade_updates] || false
        )

        result.success? ? result.charge_filter : result_error(result)
      end
    end
  end
end
