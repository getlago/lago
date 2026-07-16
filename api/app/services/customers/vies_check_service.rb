# frozen_string_literal: true

module Customers
  class ViesCheckService < BaseService
    include Customers::Concerns::EuTaxCodeResolver

    Result = BaseResult[:tax_code, :vies_check, :pending_vies_check]

    def initialize(customer:)
      @customer = customer

      super
    end

    def call
      return result.not_allowed_failure!(code: "eu_tax_not_applicable") unless customer.billing_entity.eu_tax_management

      vies_api_response = check_vies

      result.tax_code = if vies_api_response.present?
        process_vies_tax(vies_api_response)
      else
        process_not_vies_tax
      end

      SendWebhookJob.perform_after_commit(
        "customer.vies_check",
        customer,
        vies_check: vies_api_response.presence || error_vies_check
      )

      result.vies_check = vies_api_response.presence || error_vies_check
      delete_pending_vies_check_if_exists
      result
    rescue Valvat::HTTPError, Valvat::RateLimitError, Valvat::Timeout, Valvat::BlockedError,
      Valvat::InvalidRequester, Valvat::ServiceUnavailable, Valvat::MemberStateUnavailable => e
      handle_error(e)
    end

    private

    attr_reader :customer

    def handle_error(e)
      pending_vies_check = create_or_update_pending_vies_check(e)

      SendWebhookJob.perform_after_commit(
        "customer.vies_check",
        customer,
        vies_check: error_vies_check.merge(error: e.message)
      )

      result.pending_vies_check = pending_vies_check
      result.service_failure!(code: "vies_check_failed", message: e.message)
    end

    def check_vies
      return nil if customer.tax_identification_number.blank?

      # Just errors extended from Valvat::Lookup are raised, while Maintenances are not.
      # https://github.com/yolk/valvat/blob/master/README.md#handling-of-maintenance-errors
      # Check the Unavailable sheet per UE country.
      # https://ec.europa.eu/taxation_customs/vies/#/help
      Valvat.new(customer.tax_identification_number).exists?(detail: true, raise_error: true)
    end

    def error_vies_check
      {
        valid: false,
        valid_format: is_valid_vat_number?(customer.tax_identification_number)
      }
    end

    def create_or_update_pending_vies_check(exception)
      pending_check = PendingViesCheck.find_or_initialize_by(customer:)
      pending_check.assign_attributes(
        organization: customer.organization,
        billing_entity: customer.billing_entity,
        tax_identification_number: customer.tax_identification_number,
        attempts_count: pending_check.attempts_count + 1,
        last_attempt_at: Time.current,
        last_error_type: PendingViesCheck.error_type_for(exception),
        last_error_message: exception.message
      )
      pending_check.save!
      pending_check
    end

    def delete_pending_vies_check_if_exists
      customer.pending_vies_check&.destroy!
    end
  end
end
