# frozen_string_literal: true

module Mutations
  module Plans
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "plans:create"

      graphql_name "CreatePlan"
      description "Creates a new Plan"

      input_object_class Types::Plans::CreateInput
      type Types::Plans::Object

      def resolve(entitlements: nil, **args)
        args[:charges].map!(&:to_h)
        args[:fixed_charges]&.map!(&:to_h)

        # NOTE: When entitlements are provided, the plan.created webhook is emitted below, after the
        #       entitlements are persisted, so its payload includes them. Otherwise CreateService emits it.
        result = ::Plans::CreateService.call(
          args.merge(organization_id: current_organization.id),
          send_webhook: entitlements.nil?
        )

        return result_error(result) unless result.success?

        plan = result.plan

        unless entitlements.nil?
          result = ::Entitlement::PlanEntitlementsUpdateService.call(
            organization: plan.organization,
            plan:,
            entitlements_params: Utils::Entitlement.convert_gql_input_to_params(entitlements),
            partial: false,
            send_webhook: false
          )

          SendWebhookJob.perform_after_commit("plan.created", plan) if result.success?
        end

        result.success? ? plan.reload : result_error(result)
      end
    end
  end
end
