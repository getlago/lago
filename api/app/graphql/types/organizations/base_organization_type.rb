# frozen_string_literal: true

module Types
  module Organizations
    class BaseOrganizationType < BaseObject
      def billing_configuration
        {
          id: "#{object&.id}-c0nf", # Each nested object needs ID so that appollo cache system can work properly
          invoice_footer: object&.invoice_footer,
          invoice_grace_period: object&.invoice_grace_period,
          document_locale: object&.document_locale,
          eu_tax_management: object&.eu_tax_management
        }
      end
    end
  end
end
