# frozen_string_literal: true

module InvoiceCustomSections
  class UpdateService < BaseService
    Result = BaseResult[:invoice_custom_section]

    def initialize(invoice_custom_section:, update_params:)
      @update_params = update_params
      @invoice_custom_section = invoice_custom_section
      super
    end

    def call
      return result.not_found_failure!(resource: "invoice_custom_section") unless invoice_custom_section

      invoice_custom_section.update!(update_params)
      result.invoice_custom_section = invoice_custom_section
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :invoice_custom_section, :update_params
  end
end
