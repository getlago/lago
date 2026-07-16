# frozen_string_literal: true

module Api
  module V1
    module Plans
      module Entitlements
        class PrivilegesController < Api::BaseController
          before_action :find_plan
          before_action :find_entitlement

          def destroy
            result = ::Entitlement::PlanEntitlementPrivilegeDestroyService.call(
              entitlement: entitlement,
              privilege_code: params[:code]
            )

            if result.success?
              render(
                json: ::V1::Entitlement::PlanEntitlementSerializer.new(
                  result.entitlement,
                  root_name:
                )
              )
            else
              render_error_response(result)
            end
          end

          private

          attr_reader :plan, :entitlement

          def root_name
            "entitlement"
          end

          def resource_name
            "plan"
          end

          def find_plan
            @plan = current_organization.plans.parents.find_by!(
              code: params[:plan_code]
            )
          rescue ActiveRecord::RecordNotFound
            not_found_error(resource: "plan")
          end

          def find_entitlement
            @entitlement = current_organization.entitlements
              .joins(:feature)
              .where(plan: plan, entitlement_features: {code: params[:entitlement_code]})
              .includes(:feature, values: :privilege)
              .first!
          rescue ActiveRecord::RecordNotFound
            not_found_error(resource: "entitlement")
          end
        end
      end
    end
  end
end
