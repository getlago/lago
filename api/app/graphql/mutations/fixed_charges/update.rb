# frozen_string_literal: true

module Mutations
  module FixedCharges
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "charges:update"

      graphql_name "UpdateFixedCharge"
      description "Updates an existing Fixed Charge"

      input_object_class Types::FixedCharges::UpdateInput
      type Types::FixedCharges::Object

      def resolve(**args)
        fixed_charge = current_organization.fixed_charges.parents.find_by(id: args[:id])

        params = args.except(:id).to_h.deep_symbolize_keys
        params[:properties] = params[:properties].to_h if params[:properties]

        cascade_updates = params.delete(:cascade_updates) || false
        result = ::FixedCharges::UpdateService.call(fixed_charge:, params:, timestamp: Time.current.to_i, cascade_updates:)

        result.success? ? result.fixed_charge : result_error(result)
      end
    end
  end
end
