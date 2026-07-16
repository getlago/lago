# frozen_string_literal: true

module Entitlement
  class FeatureUpdateService < BaseService
    Result = BaseResult[:feature]

    def initialize(feature:, params:, partial:)
      @feature = feature
      @params = params.to_h.with_indifferent_access
      @partial = partial
      super
    end

    activity_loggable(
      action: "feature.updated",
      record: -> { feature }
    )

    def call
      return result.not_found_failure!(resource: "feature") unless feature

      if Utils::Entitlement.privilege_code_is_duplicated?(params[:privileges])
        return result.single_validation_failure!(field: :"privilege.code", error_code: "value_is_duplicated")
      end

      ActiveRecord::Base.transaction do
        update_feature_attributes
        delete_missing_privileges unless partial?
        update_privileges

        feature.save!
      end

      jobs = feature.plans.map do |plan|
        Utils::ActivityLog.produce_after_commit(plan, "plan.updated")
        SendWebhookJob.new("plan.updated", plan)
      end

      # NOTE: The webhooks are sent even if there was no actual change
      after_commit do
        ApplicationJob.perform_all_later(jobs)
        SendWebhookJob.perform_later("feature.updated", feature)
      end

      result.feature = feature
      result
    rescue ActiveRecord::RecordInvalid => e
      if e.record.is_a?(Privilege)
        errors = e.record.errors.messages.transform_keys { |key| :"privilege.#{key}" }
        result.validation_failure!(errors:)
      else
        result.record_validation_failure!(record: e.record)
      end
    end

    private

    attr_reader :feature, :params, :partial
    alias_method :partial?, :partial

    def update_feature_attributes
      feature.name = params[:name] if params.key?(:name)
      feature.description = params[:description] if params.key?(:description)
    end

    def update_privileges
      return if params[:privileges].blank?

      params[:privileges].each do |privilege_params|
        privilege = feature.privileges.find { it[:code] == privilege_params[:code] }

        if privilege.nil?
          create_privilege(privilege_params)
        else
          privilege.name = privilege_params[:name] if privilege_params.key?(:name)

          if privilege_params.dig(:config, :select_options)
            privilege.config["select_options"] ||= []
            privilege.config["select_options"] |= privilege_params[:config][:select_options]
          end

          privilege.save!
        end
      end
    end

    def create_privilege(privilege_params)
      privilege = feature.privileges.new(
        organization: feature.organization,
        code: privilege_params[:code]&.strip,
        name: privilege_params[:name]
      )
      privilege.value_type = privilege_params[:value_type] if privilege_params.has_key? :value_type
      privilege.config = privilege_params[:config] if privilege_params.has_key? :config

      privilege.save!
    end

    def delete_missing_privileges
      # Find privileges that are in the database but not in the params
      # Delete all EntitlementValues associated with those privileges
      # Then delete the privileges themselves
      missing_privilege_codes = feature.privileges.pluck(:code) - (params[:privileges] || []).pluck(:code)
      EntitlementValue.where(privilege: feature.privileges.where(code: missing_privilege_codes)).discard_all!
      feature.privileges.where(code: missing_privilege_codes).discard_all!
      missing_privilege_codes.each do |code|
        privilege = feature.privileges.find { it[:code] == code }
        next unless privilege
        privilege.discard!
      end
    end
  end
end
