# frozen_string_literal: true

module Plans
  class ChargeablesValidationService < BaseService
    Result = BaseResult

    def initialize(organization:, charges: nil, fixed_charges: nil)
      @organization = organization
      @charges = charges
      @fixed_charges = fixed_charges
      super
    end

    def call
      return result unless should_validate?

      validate_billable_metrics
      validate_add_ons

      result
    end

    private

    attr_reader :organization, :charges, :fixed_charges

    def should_validate?
      charges.present? || fixed_charges.present?
    end

    def validate_billable_metrics
      return if charges.blank?

      metric_ids = charges.map { |c| c[:billable_metric_id] }.compact.uniq
      return if metric_ids.blank?

      if organization.billable_metrics.where(id: metric_ids).count != metric_ids.count
        result.not_found_failure!(resource: "billable_metrics")
      end
    end

    def validate_add_ons
      return if fixed_charges.blank?

      validate_add_on_ids
      validate_add_on_codes
    end

    def validate_add_on_ids
      add_on_ids = fixed_charges.map { |c| c[:add_on_id] }.uniq.compact
      return if add_on_ids.blank?

      if organization.add_ons.where(id: add_on_ids).count != add_on_ids.count
        result.not_found_failure!(resource: "add_ons")
      end
    end

    def validate_add_on_codes
      add_on_codes = fixed_charges.map { |c| c[:add_on_code] }.uniq.compact
      return if add_on_codes.blank?

      if organization.add_ons.where(code: add_on_codes).count != add_on_codes.count
        result.not_found_failure!(resource: "add_ons")
      end
    end
  end
end
