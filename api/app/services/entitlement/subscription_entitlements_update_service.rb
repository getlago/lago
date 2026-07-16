# frozen_string_literal: true

module Entitlement
  class SubscriptionEntitlementsUpdateService < BaseService
    include ::Entitlement::Concerns::CreateOrUpdateConcern

    Result = BaseResult

    def initialize(subscription:, entitlements_params:, partial:)
      @subscription = subscription
      @entitlements_params = entitlements_params.to_h.with_indifferent_access
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
        remove_or_delete_missing_features if full?
        update_entitlements
      end

      # NOTE: The webhooks is sent even if no changes were made to the subscription
      SendWebhookJob.perform_after_commit("subscription.updated", subscription)

      result
    rescue BaseService::FailedResult => e
      result.fail_with_error!(e)
    rescue ActiveRecord::RecordInvalid => e
      if e.record.is_a?(EntitlementValue)
        errors = e.record.errors.messages.transform_keys { |key| :"privilege.#{key}" }
        result.validation_failure!(errors:)
      else
        result.record_validation_failure!(record: e.record)
      end
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

    attr_reader :subscription, :entitlements_params, :partial
    delegate :organization, to: :subscription
    alias_method :partial?, :partial

    def full?
      !partial?
    end

    def remove_or_delete_missing_features
      missing_codes = (SubscriptionEntitlement.for_subscription(subscription).map(&:code) - entitlements_params.keys).uniq

      # If the feature was added as a subscription override, delete it
      sub_entitlements = subscription.entitlements.joins(:feature).where(feature: {code: missing_codes})
      EntitlementValue.where(entitlement: sub_entitlements).update_all(deleted_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      sub_entitlements.update_all(deleted_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

      # If the feature is from the plan, create a SubscriptionFeatureRemoval
      plan_entitlements = subscription.plan.entitlements.joins(:feature).where(feature: {code: missing_codes})
      plan_entitlements.each do |entitlement|
        SubscriptionFeatureRemoval.create!(
          organization: subscription.organization,
          feature: entitlement.feature,
          subscription: subscription
        )
      end

      # If there was any privilege removal for a removed feature, we clean them up
      subscription.entitlement_removals.where(
        privilege: Privilege.joins(:feature).where(feature: {code: missing_codes})
      ).update_all(deleted_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end

    def update_entitlements
      return if entitlements_params.blank?

      plan = subscription.plan.parent || subscription.plan

      features_by_code = organization.features
        .where(code: entitlements_params.keys)
        .includes(:privileges)
        .index_by(&:code)

      # NOTE: Some feature code were not found
      if features_by_code.size != entitlements_params.size
        return result.not_found_failure!(resource: "feature")
      end

      feature_ids = features_by_code.values.map(&:id)

      plan_entitlements_by_feature_id = plan.entitlements
        .where(entitlement_feature_id: feature_ids)
        .includes(values: :privilege)
        .index_by(&:entitlement_feature_id)

      sub_entitlements_by_feature_id = subscription.entitlements
        .where(entitlement_feature_id: feature_ids)
        .includes(values: :privilege)
        .index_by(&:entitlement_feature_id)

      entitlements_params.each do |feature_code, privilege_params|
        feature = features_by_code[feature_code]

        SubscriptionEntitlementCoreUpdateService.call!(
          subscription:,
          plan:,
          feature:,
          privilege_params:,
          plan_entitlement: plan_entitlements_by_feature_id[feature.id],
          sub_entitlement: sub_entitlements_by_feature_id[feature.id],
          partial:
        )
      end
    end
  end
end
