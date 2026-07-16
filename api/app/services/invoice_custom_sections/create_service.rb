# frozen_string_literal: true

module InvoiceCustomSections
  class CreateService < BaseService
    Result = BaseResult[:invoice_custom_section]

    def initialize(organization:, create_params:)
      @organization = organization
      @create_params = create_params
      super
    end

    def call
      invoice_custom_section = organization.invoice_custom_sections.create!(create_params)
      result.invoice_custom_section = invoice_custom_section
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :organization, :create_params
  end
end
