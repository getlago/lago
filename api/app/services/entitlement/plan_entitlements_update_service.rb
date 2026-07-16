# frozen_string_literal: true

module Entitlement
  class PlanEntitlementsUpdateService < BaseService
    include ::Entitlement::Concerns::CreateOrUpdateConcern

    Result = BaseResult[:entitlements]

    def initialize(organization:, plan:, entitlements_params:, partial:, send_webhook: true)
      @organization = organization
      @plan = plan
      @entitlements_params = entitlements_params.to_h.with_indifferent_access
      @partial = partial
      @send_webhook = send_webhook
      super
    end

    # NOTE: send_webhook gates the activity log too: both represent the same plan.updated event.
    #       It is set to false when invoked from the plan create/update mutations, where the plan
    #       service already emits the plan event, to avoid duplicates.
    activity_loggable(
      action: "plan.updated",
      record: -> { plan },
      condition: -> { send_webhook }
    )

    def call
      return result.not_found_failure!(resource: "plan") unless plan

      ActiveRecord::Base.transaction do
        delete_missing_entitlements unless partial?
        update_entitlements
      end

      # NOTE: The webhook is sent even if no changes were made to the plan
      SendWebhookJob.perform_after_commit("plan.updated", plan) if send_webhook

      result.entitlements = plan.entitlements.includes(:feature, values: :privilege).reload
      result
    rescue ValidationFailure => e
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

    attr_reader :organization, :plan, :entitlements_params, :partial, :send_webhook
    alias_method :partial?, :partial

    def delete_missing_entitlements
      missing = plan.entitlements.joins(:feature).where.not(feature: {code: entitlements_params.keys})
      EntitlementValue.where(entitlement: missing).discard_all!
      missing.discard_all!
    end

    def delete_missing_entitlement_values(entitlement, privilege_values)
      return if privilege_values.blank?

      entitlement.values.joins(:privilege).where.not(privilege: {code: privilege_values.keys}).discard_all!
    end

    def update_entitlements
      return if entitlements_params.blank?

      entitlements_params.each do |feature_code, privilege_values|
        feature = organization.features.includes(:privileges).find { it.code == feature_code }

        raise ActiveRecord::RecordNotFound.new("Entitlement::Feature") unless feature

        # Find existing entitlement or create new one
        entitlement = plan.entitlements.includes(:values).find { it.entitlement_feature_id == feature.id }

        if entitlement.nil?
          entitlement = Entitlement.create!(
            organization: organization,
            feature: feature,
            plan: plan
          )
        elsif !partial?
          delete_missing_entitlement_values(entitlement, privilege_values)
        end

        update_entitlement_values(entitlement, feature, privilege_values)
      end
    end

    def create_entitlement_values(entitlement, feature, privilege_values)
      privilege_values.each do |privilege_code, value|
        privilege = feature.privileges.find { it.code == privilege_code }

        raise ActiveRecord::RecordNotFound.new("Entitlement::Privilege") unless privilege

        create_entitlement_value(entitlement, privilege, value)
      end
    end

    def update_entitlement_values(entitlement, feature, privilege_values)
      return if privilege_values.blank?

      privilege_values.each do |privilege_code, value|
        privilege = feature.privileges.find { it.code == privilege_code }

        raise ActiveRecord::RecordNotFound.new("Entitlement::Privilege") unless privilege

        entitlement_value = entitlement.values.find { it.entitlement_privilege_id == privilege.id }

        if entitlement_value
          entitlement_value.update!(value: validate_value(value, privilege))
        else
          create_entitlement_value(entitlement, privilege, value)
        end
      end
    end

    def create_entitlement_value(entitlement, privilege, value)
      EntitlementValue.create!(
        organization: organization,
        entitlement: entitlement,
        privilege: privilege,
        value: validate_value(value, privilege)
      )
    end
  end
end
