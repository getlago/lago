# frozen_string_literal: true

module Entitlement
  class SubscriptionFeaturePrivilegeRemoveService < BaseService
    Result = BaseResult[:feature_code, :privilege_code]

    def initialize(subscription:, feature_code:, privilege_code:)
      @subscription = subscription
      @feature_code = feature_code
      @privilege_code = privilege_code
      super
    end

    activity_loggable(
      action: "subscription.updated",
      record: -> { subscription }
    )

    def call
      return result.not_found_failure!(resource: "subscription") unless subscription
      return result.not_found_failure!(resource: "feature") unless feature
      return result.not_found_failure!(resource: "privilege") unless privilege

      ActiveRecord::Base.transaction do
        delete_subscription_entitlement_value_if_exists
        add_privilege_removal_if_privilege_is_in_plan
      end

      SendWebhookJob.perform_after_commit("subscription.updated", subscription)

      result.feature_code = feature_code
      result.privilege_code = privilege_code
      result
    end

    private

    attr_reader :subscription, :feature_code, :privilege_code
    delegate :organization, to: :subscription

    def feature
      @feature ||= organization.features.find_by(code: feature_code)
    end

    def privilege
      @privilege ||= organization.privileges.find_by(code: privilege_code, feature:)
    end

    def delete_subscription_entitlement_value_if_exists
      entitlement = subscription.entitlements.find_by(feature: feature)
      return unless entitlement
      entitlement.values.where(privilege:).update_all(deleted_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end

    def add_privilege_removal_if_privilege_is_in_plan
      plan_id = subscription.plan.parent_id || subscription.plan.id
      return unless Entitlement.where(plan_id:, feature:).exists?

      SubscriptionFeatureRemoval.insert_all( # rubocop:disable Rails/SkipsModelValidations
        [{organization_id: organization.id, subscription_id: subscription.id, entitlement_privilege_id: privilege.id}],
        unique_by: :idx_unique_privilege_removal_per_subscription
      )
    end
  end
end
