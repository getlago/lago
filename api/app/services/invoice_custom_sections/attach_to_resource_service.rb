# frozen_string_literal: true

module InvoiceCustomSections
  class AttachToResourceService < BaseService
    Result = BaseResult

    def initialize(resource:, params:)
      super

      @resource = resource
      @params = params
    end

    def call
      return result unless params.key?(:invoice_custom_section)

      ActiveRecord::Base.transaction do
        if skip_flag.nil?
          handle_implicit_skip_flag
        else
          handle_explicit_skip_flag
        end
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :resource, :params

    def skip_sections?
      skip_flag == true
    end

    def skip_flag
      params.dig(:invoice_custom_section, :skip_invoice_custom_sections)
    end

    def sections_param
      key = api_context? ? :invoice_custom_section_codes : :invoice_custom_section_ids

      params.dig(:invoice_custom_section, key)
    end

    def handle_explicit_skip_flag
      if skip_sections?
        resource.update!(skip_invoice_custom_sections: true)
        resource.applied_invoice_custom_sections.destroy_all
      else
        resource.update!(skip_invoice_custom_sections: false)
        attach_sections unless sections_param.nil?
      end
    end

    def handle_implicit_skip_flag
      return if resource.skip_invoice_custom_sections

      attach_sections unless sections_param.nil?
    end

    def attach_sections
      existing_section_ids = resource.applied_invoice_custom_sections.pluck(:invoice_custom_section_id)
      new_section_ids = invoice_custom_sections.pluck(:id)

      invoice_custom_sections.each do |section|
        next if existing_section_ids.include?(section.id)

        resource.applied_invoice_custom_sections.create!(
          invoice_custom_section: section,
          organization: resource.organization
        )
      end

      remove_obsolete_sections(existing_section_ids, new_section_ids)
    end

    def remove_obsolete_sections(existing_ids, new_ids)
      obsolete_ids = existing_ids - new_ids

      resource.applied_invoice_custom_sections.where(invoice_custom_section_id: obsolete_ids).destroy_all if obsolete_ids.any?
    end

    def invoice_custom_sections
      return @invoice_custom_sections if defined?(@invoice_custom_sections)
      return @invoice_custom_sections = [] if section_identifiers.blank?

      identifier = api_context? ? :code : :id
      @invoice_custom_sections =
        resource.organization.invoice_custom_sections.where(identifier => section_identifiers)
    end

    def section_identifiers
      return @section_identifiers if defined?(@section_identifiers)
      return @section_identifiers = [] if sections_param.blank?

      key = api_context? ? :invoice_custom_section_codes : :invoice_custom_section_ids
      @section_identifiers = params.dig(:invoice_custom_section, key)&.compact&.uniq || []
    end
  end
end
