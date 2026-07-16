# frozen_string_literal: true

module InvoiceCustomSections
  class DeselectAllService < BaseService
    Result = BaseResult[:invoice_custom_section]

    def initialize(section:)
      @section = section
      super
    end

    def call
      section.billing_entity_applied_invoice_custom_sections.destroy_all
      section.customer_applied_invoice_custom_sections.destroy_all

      result.invoice_custom_section = section
      result
    end

    private

    attr_reader :section
  end
end
