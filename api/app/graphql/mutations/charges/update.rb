# frozen_string_literal: true

module Mutations
  module Charges
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "charges:update"

      graphql_name "UpdateCharge"
      description "Updates an existing Charge"

      input_object_class Types::Charges::UpdateInput
      type Types::Charges::Object

      def resolve(**args)
        charge = current_organization.charges.parents.find_by(id: args[:id])

        params = args.except(:id).to_h.deep_symbolize_keys
        params[:properties] = params[:properties].to_h if params[:properties]
        params[:filters]&.map!(&:to_h)
        params[:applied_pricing_unit] = params[:applied_pricing_unit].to_h if params[:applied_pricing_unit]

        cascade_updates = params.delete(:cascade_updates) || false
        result = ::Charges::UpdateService.call(charge:, params:, cascade_updates:)

        result.success? ? result.charge : result_error(result)
      end
    end
  end
end
