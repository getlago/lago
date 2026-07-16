# frozen_string_literal: true

module Api
  module V1
    module Subscriptions
      class EntitlementsController < Api::BaseController
        # Shall we update BaseController to include hae active subscriptions only?
        before_action :find_subscription

        def index
          render(
            json: ::CollectionSerializer.new(
              Entitlement::SubscriptionEntitlement.for_subscription(subscription),
              ::V1::Entitlement::SubscriptionEntitlementSerializer,
              collection_name: "entitlements"
            )
          )
        end

        def update
          result = ::Entitlement::SubscriptionEntitlementsUpdateService.call(
            subscription: subscription,
            entitlements_params: update_params,
            partial: true
          )

          if result.success?
            render(
              json: ::CollectionSerializer.new(
                Entitlement::SubscriptionEntitlement.for_subscription(subscription),
                ::V1::Entitlement::SubscriptionEntitlementSerializer,
                collection_name: "entitlements"
              )
            )
          else
            render_error_response(result)
          end
        end

        def destroy
          result = ::Entitlement::SubscriptionFeatureRemoveService.call(subscription:, feature_code: params[:code])

          if result.success?
            render(
              json: ::CollectionSerializer.new(
                Entitlement::SubscriptionEntitlement.for_subscription(subscription),
                ::V1::Entitlement::SubscriptionEntitlementSerializer,
                collection_name: "entitlements"
              )
            )
          else
            render_error_response(result)
          end
        end

        private

        attr_reader :subscription

        def resource_name
          "subscription"
        end

        def update_params
          params.fetch(:entitlements, {}).permit!
        end

        def find_subscription
          @subscription = current_organization.subscriptions
            .order("terminated_at DESC NULLS FIRST, started_at DESC") # TODO: Confirm
            .find_by!(
              external_id: params[:subscription_external_id],
              # we're keeping both `subscription_status` and `status` for backward compatibility,
              # but we should rely more on the `subscription_status`
              status: params[:subscription_status] || params[:status] || :active
            )
        rescue ActiveRecord::RecordNotFound
          not_found_error(resource: "subscription")
        end
      end
    end
  end
end
