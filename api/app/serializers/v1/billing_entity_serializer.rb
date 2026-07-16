# frozen_string_literal: true

module V1
  class BillingEntitySerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        code: model.code,
        name: model.name,
        default_currency: model.default_currency,
        created_at: model.created_at.iso8601,
        updated_at: model.updated_at.iso8601,
        country: model.country,
        address_line1: model.address_line1,
        address_line2: model.address_line2,
        phone: model.phone,
        city: model.city,
        state: model.state,
        zipcode: model.zipcode,
        einvoicing: model.einvoicing,
        email: model.email,
        legal_name: model.legal_name,
        legal_number: model.legal_number,
        timezone: model.timezone,
        net_payment_term: model.net_payment_term,
        email_settings: model.email_settings,
        document_numbering: model.document_numbering,
        document_number_prefix: model.document_number_prefix,
        tax_identification_number: model.tax_identification_number,
        finalize_zero_amount_invoice: model.finalize_zero_amount_invoice,
        invoice_footer: model.invoice_footer,
        invoice_grace_period: model.invoice_grace_period,
        subscription_invoice_issuing_date_adjustment: model.subscription_invoice_issuing_date_adjustment,
        subscription_invoice_issuing_date_anchor: model.subscription_invoice_issuing_date_anchor,
        document_locale: model.document_locale,
        is_default: model.organization.default_billing_entity&.id == model.id,
        eu_tax_management: model.eu_tax_management,
        logo_url: model.logo_url
      }

      payload = payload.merge(taxes) if include?(:taxes)
      payload = payload.merge(selected_invoice_custom_sections) if include?(:selected_invoice_custom_sections)

      payload
    end

    private

    def taxes
      ::CollectionSerializer.new(
        model.taxes,
        ::V1::TaxSerializer,
        collection_name: "taxes"
      ).serialize
    end

    def selected_invoice_custom_sections
      ::CollectionSerializer.new(
        model.selected_invoice_custom_sections,
        ::V1::InvoiceCustomSectionSerializer,
        collection_name: "selected_invoice_custom_sections"
      ).serialize
    end
  end
end
