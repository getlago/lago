# frozen_string_literal: true

module Entitlement
  class SubscriptionEntitlementUpdateService < BaseService
    include ::Entitlement::Concerns::CreateOrUpdateConcern

    Result = BaseResult[:entitlement]

    def initialize(subscription:, feature_code:, privilege_params:, partial:)
      @subscription = subscription
      @feature_code = feature_code
      @privilege_params = privilege_params.to_h.with_indifferent_access
      @partial = partial
      super
    end

    activity_loggable(
      action: "subscription.updated",
      record: -> { subscription }
    )

    def call
      return result.not_found_failure!(resource: "subscription") unless subscription

      ActiveRecord::Base.transaction do
        plan = subscription.plan.parent || subscription.plan
        feature = organization.features.includes(:privileges).find_by!(code: feature_code)

        SubscriptionEntitlementCoreUpdateService.call!(
          subscription:,
          plan:,
          feature:,
          plan_entitlement: plan.entitlements.includes(values: :privilege).find_by(feature:),
          sub_entitlement: subscription.entitlements.includes(values: :privilege).find_by(feature:),
          privilege_params:,
          partial:
        )
      end

      # NOTE: The webhooks is sent even if no changes were made to the subscription
      SendWebhookJob.perform_after_commit("subscription.updated", subscription)

      result.entitlement = SubscriptionEntitlement.for_subscription(subscription).find { it.code == feature_code }

      result
    rescue BaseService::FailedResult => e
      result.fail_with_error!(e)
    rescue ActiveRecord::RecordNotFound => e
      if e.message.include?("Entitlement::Feature")
        result.not_found_failure!(resource: "feature")
      elsif e.message.include?("Entitlement::Privilege")
        result.not_found_failure!(resource: "privilege")
      else
        result.not_found_failure!(resource: "record")
      end
    end

    private

    attr_reader :subscription, :feature_code, :privilege_params, :partial
    delegate :organization, to: :subscription
  end
end
