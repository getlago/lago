# frozen_string_literal: true

module Mutations
  module Charges
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "charges:create"

      graphql_name "CreateCharge"
      description "Creates a new Charge for a Plan"

      input_object_class Types::Charges::CreateInput
      type Types::Charges::Object

      def resolve(**args)
        plan = current_organization.plans.parents.find_by(id: args[:plan_id])

        params = args.except(:plan_id).to_h.deep_symbolize_keys
        cascade_updates = params.delete(:cascade_updates) || false
        params[:properties] = params[:properties].to_h if params[:properties]
        params[:filters]&.map!(&:to_h)
        params[:applied_pricing_unit] = params[:applied_pricing_unit].to_h if params[:applied_pricing_unit]

        result = ::Charges::CreateService.call(plan:, params:, cascade_updates:)

        result.success? ? result.charge : result_error(result)
      end
    end
  end
end
