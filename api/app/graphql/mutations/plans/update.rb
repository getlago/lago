# frozen_string_literal: true

module Mutations
  module Plans
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "plans:update"

      graphql_name "UpdatePlan"
      description "Updates an existing Plan"

      input_object_class Types::Plans::UpdateInput
      type Types::Plans::Object

      def resolve(entitlements: nil, **args)
        args[:charges]&.map!(&:to_h)
        args[:fixed_charges]&.map!(&:to_h)
        plan = current_organization.plans.find_by(id: args[:id])

        # NOTE: When entitlements are provided, the plan.updated webhook is emitted below, after the
        #       entitlements are persisted, so its payload includes them. Otherwise UpdateService emits it.
        result = ::Plans::UpdateService.call(plan:, params: args, send_webhook: entitlements.nil?)

        return result_error(result) unless result.success?

        unless entitlements.nil?
          result = ::Entitlement::PlanEntitlementsUpdateService.call(
            organization: plan.organization,
            plan:,
            entitlements_params: Utils::Entitlement.convert_gql_input_to_params(entitlements),
            partial: false,
            send_webhook: false
          )

          SendWebhookJob.perform_after_commit("plan.updated", plan) if result.success?
        end

        result.success? ? plan.reload : result_error(result)
      end
    end
  end
end
