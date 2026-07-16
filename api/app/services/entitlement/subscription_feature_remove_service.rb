# frozen_string_literal: true

module Entitlement
  class SubscriptionFeatureRemoveService < BaseService
    Result = BaseResult[:feature_code]

    def initialize(subscription:, feature_code:)
      @subscription = subscription
      @feature_code = feature_code
      super
    end

    activity_loggable(
      action: "subscription.updated",
      record: -> { subscription }
    )

    def call
      return result.not_found_failure!(resource: "subscription") unless subscription
      return result.not_found_failure!(resource: "feature") unless feature

      ActiveRecord::Base.transaction do
        delete_subscription_entitlement_if_exists
        delete_privilege_removals_if_exists
        add_feature_removal_if_feature_is_in_plan
      end

      SendWebhookJob.perform_after_commit("subscription.updated", subscription)

      result.feature_code = feature_code
      result
    end

    private

    attr_reader :subscription, :feature_code
    delegate :organization, to: :subscription

    def feature
      @feature ||= subscription.organization.features.find_by(code: feature_code)
    end

    def delete_subscription_entitlement_if_exists
      entitlement = subscription.entitlements.find_by(feature:)
      return unless entitlement
      entitlement.values.update_all(deleted_at: Time.zone.now) # rubocop:disable Rails/SkipsModelValidations
      entitlement.discard!
    end

    def delete_privilege_removals_if_exists
      subscription.entitlement_removals.where(privilege: feature.privileges).update_all(deleted_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end

    def add_feature_removal_if_feature_is_in_plan
      plan_id = subscription.plan.parent_id || subscription.plan.id
      return unless Entitlement.where(plan_id: plan_id, entitlement_feature_id: feature.id).exists?

      SubscriptionFeatureRemoval.insert_all( # rubocop:disable Rails/SkipsModelValidations
        [{organization_id: organization.id, subscription_id: subscription.id, entitlement_feature_id: feature.id}],
        unique_by: :idx_unique_feature_removal_per_subscription
      )
    end
  end
end
