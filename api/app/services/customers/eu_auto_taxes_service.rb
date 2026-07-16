# frozen_string_literal: true

module Customers
  class EuAutoTaxesService < BaseService
    include Customers::Concerns::EuTaxCodeResolver

    Result = BaseResult[:tax_code]

    B2B_ONLY_TERRITORY_COUNTRIES = %w[FR].freeze

    def initialize(customer:, new_record:, tax_attributes_changed:)
      @customer = customer
      @new_record = new_record
      @tax_attributes_changed = tax_attributes_changed

      super
    end

    def call
      return result.not_allowed_failure!(code: "eu_tax_not_applicable") unless should_apply_eu_taxes?

      territory_tax_code = detect_special_territory
      if territory_tax_code
        result.tax_code = territory_tax_code
        delete_pending_vies_check_if_exists
        return result
      end

      if customer.tax_identification_number.present?
        schedule_async_vies_check
        return result.service_failure!(code: "vies_check_pending", message: "VIES check scheduled asynchronously")
      end

      result.tax_code = process_not_vies_tax
      delete_pending_vies_check_if_exists
      result
    end

    private

    attr_reader :customer, :tax_attributes_changed, :new_record

    def detect_special_territory
      country_code = customer.country&.upcase
      return if country_code.blank? || customer.zipcode.blank?

      tax_exception = find_territory_tax_exception(country_code)
      return unless tax_exception

      territory_tax_code(country_code, tax_exception)
    end

    def find_territory_tax_exception(country_code)
      return unless eu_countries_code.include?(country_code)

      tax_exceptions = LagoEuVat::Rate.country_rates(country_code:)[:exceptions]
      return if tax_exceptions.blank?

      normalized_zip = customer.zipcode.gsub(/\s/, "")
      tax_exceptions.find { |tax_exception| normalized_zip.match?(tax_exception["postcode"]) }
    end

    def territory_tax_code(country_code, tax_exception)
      return if B2B_ONLY_TERRITORY_COUNTRIES.include?(country_code) && !is_b2b?

      exception_code = tax_exception["name"].parameterize.underscore
      "lago_eu_#{country_code.downcase}_exception_#{exception_code}"
    end

    def is_b2b?
      customer.tax_identification_number.present? && is_valid_vat_number?(customer.tax_identification_number)
    end

    def should_apply_eu_taxes?
      return false unless customer.billing_entity.eu_tax_management
      return true if new_record

      non_existing_eu_taxes = customer.taxes.where("code ILIKE ?", "lago_eu%").none?

      non_existing_eu_taxes || tax_attributes_changed
    end

    def schedule_async_vies_check
      PendingViesCheck.find_or_initialize_by(customer:).update!(
        organization: customer.organization,
        billing_entity: customer.billing_entity,
        tax_identification_number: customer.tax_identification_number,
        attempts_count: 0,
        last_attempt_at: nil,
        last_error_type: nil,
        last_error_message: nil
      )

      Customers::ViesCheckJob.perform_after_commit(customer)
    end

    def delete_pending_vies_check_if_exists
      customer.pending_vies_check&.destroy!
    end
  end
end
