# frozen_string_literal: true

module V1
  class OrganizationSerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        name: model.name,
        slug: model.slug,
        default_currency: model.default_currency,
        created_at: model.created_at.iso8601,
        webhook_url: webhook_urls.first.to_s,
        webhook_urls:,
        country: model.country,
        address_line1: model.address_line1,
        address_line2: model.address_line2,
        state: model.state,
        zipcode: model.zipcode,
        email: model.email,
        city: model.city,
        legal_name: model.legal_name,
        legal_number: model.legal_number,
        timezone: model.timezone,
        net_payment_term: model.net_payment_term,
        email_settings: model.email_settings,
        document_numbering: model.document_numbering,
        document_number_prefix: model.document_number_prefix,
        tax_identification_number: model.tax_identification_number,
        finalize_zero_amount_invoice: model.finalize_zero_amount_invoice,
        billing_configuration:,
        events_store: model.events_store
      }

      payload = payload.merge(taxes) if include?(:taxes)

      payload
    end

    private

    def billing_configuration
      {
        invoice_footer: model.invoice_footer,
        invoice_grace_period: model.invoice_grace_period,
        document_locale: model.document_locale
      }
    end

    def taxes
      ::CollectionSerializer.new(
        model.taxes.applied_to_organization,
        ::V1::TaxSerializer,
        collection_name: "taxes"
      ).serialize
    end

    def webhook_urls
      model.webhook_endpoints.map(&:webhook_url)
    end
  end
end
