# frozen_string_literal: true

module Invoices
  class ApplyInvoiceCustomSectionsService < BaseService
    Result = BaseResult[:applied_sections]

    def initialize(invoice:, resources: [], custom_section_ids: [])
      @invoice = invoice
      @customer = invoice.customer
      @resources = resources
      @custom_section_ids = custom_section_ids

      super()
    end

    def call
      result.applied_sections = []
      return result if skip_custom_sections?

      applicable_sections.each do |custom_section|
        invoice.applied_invoice_custom_sections.create!(
          organization_id: invoice.organization_id,
          code: custom_section.code,
          details: custom_section.details,
          display_name: custom_section.display_name,
          name: custom_section.name
        )
      end
      result.applied_sections = invoice.applied_invoice_custom_sections
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :invoice, :customer, :resources, :custom_section_ids

    def skip_custom_sections?
      return false if participating_resources.any? { |r| resource_has_invoice_custom_sections?(r) }
      return true if resources.any? && participating_resources.none?
      return false if custom_section_ids.present?

      customer.skip_invoice_custom_sections
    end

    def applicable_sections
      manual_sections = if custom_section_ids.present?
        organization.invoice_custom_sections.where(id: custom_section_ids)
      elsif resources.any?
        sections_from_resources
      else
        customer.configurable_invoice_custom_sections
      end

      manual_sections | customer.system_generated_invoice_custom_sections
    end

    def sections_from_resources
      with_ics, without_ics = participating_resources.partition { |r| resource_has_invoice_custom_sections?(r) }

      return customer.configurable_invoice_custom_sections if with_ics.empty?

      sections = with_ics.flat_map(&:selected_invoice_custom_sections).uniq
      sections |= customer.configurable_invoice_custom_sections if without_ics.any?

      sections
    end

    def participating_resources
      @participating_resources ||= resources.reject(&:skip_invoice_custom_sections)
    end

    def resource_has_invoice_custom_sections?(resource)
      return false unless resource&.respond_to?(:selected_invoice_custom_sections)

      resource.selected_invoice_custom_sections.any?
    end

    def organization
      @organization ||= invoice.organization
    end
  end
end
