# frozen_string_literal: true

module Mutations
  module FixedCharges
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "charges:create"

      graphql_name "CreateFixedCharge"
      description "Creates a new Fixed Charge for a Plan"

      input_object_class Types::FixedCharges::CreateInput
      type Types::FixedCharges::Object

      def resolve(**args)
        plan = current_organization.plans.parents.find_by(id: args[:plan_id])

        params = args.except(:plan_id).to_h.deep_symbolize_keys
        cascade_updates = params.delete(:cascade_updates) || false
        params[:properties] = params[:properties].to_h if params[:properties]

        result = ::FixedCharges::CreateService.call(plan:, params:, cascade_updates:)

        result.success? ? result.fixed_charge : result_error(result)
      end
    end
  end
end
