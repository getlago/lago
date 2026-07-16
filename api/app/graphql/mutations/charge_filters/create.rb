# frozen_string_literal: true

module Mutations
  module ChargeFilters
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "charges:create"

      graphql_name "CreateChargeFilter"
      description "Creates a new Charge Filter"

      input_object_class Types::ChargeFilters::CreateInput
      type Types::ChargeFilters::Object

      def resolve(**args)
        charge = current_organization.charges.parents.find_by(id: args[:charge_id])

        params = args.except(:charge_id).to_h.deep_symbolize_keys
        cascade_updates = params.delete(:cascade_updates) || false
        params[:properties] = params[:properties].to_h if params[:properties]

        result = ::ChargeFilters::CreateService.call(charge:, params:, cascade_updates:)

        result.success? ? result.charge_filter : result_error(result)
      end
    end
  end
end
