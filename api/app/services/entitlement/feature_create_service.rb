# frozen_string_literal: true

module Entitlement
  class FeatureCreateService < BaseService
    Result = BaseResult[:feature]

    def initialize(organization:, params:)
      @organization = organization
      @params = params.to_h.with_indifferent_access
      super
    end

    activity_loggable(
      action: "feature.created",
      record: -> { result.feature }
    )

    def call
      return result.not_found_failure!(resource: "organization") unless organization

      if Utils::Entitlement.privilege_code_is_duplicated?(params[:privileges])
        return result.single_validation_failure!(field: :"privilege.code", error_code: "value_is_duplicated")
      end

      ActiveRecord::Base.transaction do
        feature = Feature.create!(
          organization:,
          code: params[:code]&.strip,
          name: params[:name],
          description: params[:description]
        )

        if params[:privileges].present?
          create_privileges(feature, params[:privileges])
        end

        result.feature = feature
      end

      SendWebhookJob.perform_after_commit("feature.created", result.feature)

      result
    rescue ActiveRecord::RecordInvalid => e
      if e.record.is_a?(Privilege)
        # because you can get "code" error from feature or privilege, I think prefixing the field name is helpful!
        errors = e.record.errors.messages.transform_keys { |key| :"privilege.#{key}" }
        result.validation_failure!(errors:)
      else
        result.record_validation_failure!(record: e.record)
      end
    rescue ActiveRecord::RecordNotUnique
      result.single_validation_failure!(field: :code, error_code: "value_already_exist")
    end

    private

    attr_reader :organization, :params

    def create_privileges(feature, privileges_params)
      privileges_params.each do |privilege_params|
        privilege = feature.privileges.new(
          organization:,
          code: privilege_params[:code]&.strip,
          name: privilege_params[:name]
        )
        privilege.value_type = privilege_params[:value_type] if privilege_params.has_key? :value_type
        privilege.config = privilege_params[:config] if privilege_params.has_key? :config

        privilege.save!
      end
    end
  end
end
