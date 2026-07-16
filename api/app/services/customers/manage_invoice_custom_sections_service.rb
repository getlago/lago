# frozen_string_literal: true

module Customers
  class ManageInvoiceCustomSectionsService < BaseService
    Result = BaseResult[:customer]

    def initialize(customer:, skip_invoice_custom_sections:, section_ids: nil, section_codes: nil)
      @customer = customer
      @section_ids = section_ids
      @section_codes = section_codes
      @skip_invoice_custom_sections = skip_invoice_custom_sections

      super
    end

    def call
      return result.not_found_failure!(resource: "customer") unless customer
      return fail_with_double_selection if !section_ids.nil? && !section_codes.nil?
      return fail_with_invalid_params if skip_invoice_custom_sections && !(section_ids || section_codes).nil?

      ActiveRecord::Base.transaction do
        if !skip_invoice_custom_sections.nil?
          customer.selected_invoice_custom_sections = InvoiceCustomSection.none if !!skip_invoice_custom_sections
          customer.skip_invoice_custom_sections = skip_invoice_custom_sections
        end

        if !section_ids.nil? || !section_codes.nil?
          customer.skip_invoice_custom_sections = false

          assign_selected_sections unless selected_sections_match?
        end
        customer.save!
      end

      result.customer = customer
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :customer, :section_ids, :skip_invoice_custom_sections, :section_codes

    def fail_with_double_selection
      result.validation_failure!(errors: {invoice_custom_sections: ["section_ids_and_section_codes_sent_together"]})
    end

    def fail_with_invalid_params
      result.validation_failure!(errors: {invoice_custom_sections: ["skip_sections_and_selected_ids_sent_together"]})
    end

    def selected_sections_match?
      customer.selected_invoice_custom_sections.ids == section_ids ||
        customer.selected_invoice_custom_sections.map(&:code) == section_codes
    end

    def assign_selected_sections
      # Note: when assigning billing entity's sections, an empty array will be sent
      selected_sections = if section_ids
        customer.organization.invoice_custom_sections.where(id: section_ids)
      elsif section_codes
        customer.organization.invoice_custom_sections.where(code: section_codes)
      else
        InvoiceCustomSection.none
      end

      system_generated_sections = customer.system_generated_invoice_custom_sections

      # Clear existing manual sections
      customer.applied_invoice_custom_sections.where.not(invoice_custom_section: system_generated_sections).destroy_all

      # Create new join records for selected sections
      selected_sections.each do |section|
        customer.applied_invoice_custom_sections.create!(
          organization_id: customer.organization_id,
          billing_entity_id: customer.billing_entity_id,
          invoice_custom_section: section
        )
      end
    end
  end
end
