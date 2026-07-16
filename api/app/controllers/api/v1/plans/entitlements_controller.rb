# frozen_string_literal: true

module Api
  module V1
    module Plans
      class EntitlementsController < BaseController
        before_action :find_entitlement, only: %i[show destroy]

        def index
          entitlements = current_organization.entitlements
            .where(plan: plan)
            .includes(:feature, values: :privilege)

          render(
            json: ::CollectionSerializer.new(
              entitlements,
              ::V1::Entitlement::PlanEntitlementSerializer,
              collection_name: "entitlements"
            )
          )
        end

        def show
          render(
            json: ::V1::Entitlement::PlanEntitlementSerializer.new(
              entitlement,
              root_name:
            )
          )
        end

        def create
          result = ::Entitlement::PlanEntitlementsUpdateService.call(
            organization: current_organization,
            plan:,
            entitlements_params: update_params,
            partial: false
          )

          if result.success?
            render(
              json: ::CollectionSerializer.new(
                result.entitlements,
                ::V1::Entitlement::PlanEntitlementSerializer,
                collection_name: "entitlements"
              )
            )
          else
            render_error_response(result)
          end
        end

        def update
          result = ::Entitlement::PlanEntitlementsUpdateService.call(
            organization: current_organization,
            plan:,
            entitlements_params: update_params,
            partial: true
          )

          if result.success?
            render(
              json: ::CollectionSerializer.new(
                result.entitlements,
                ::V1::Entitlement::PlanEntitlementSerializer,
                collection_name: "entitlements"
              )
            )
          else
            render_error_response(result)
          end
        end

        def destroy
          result = ::Entitlement::PlanEntitlementDestroyService.call(entitlement: entitlement)

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

        def update_params
          params.fetch(:entitlements, {}).permit!
        end

        def root_name
          "entitlement"
        end

        def resource_name
          "plan"
        end

        def find_entitlement
          @entitlement = current_organization.entitlements
            .joins(:feature)
            .where(plan: plan, entitlement_features: {code: params[:code]})
            .includes(:feature, values: :privilege)
            .first!
        rescue ActiveRecord::RecordNotFound
          not_found_error(resource: "entitlement")
        end
      end
    end
  end
end
