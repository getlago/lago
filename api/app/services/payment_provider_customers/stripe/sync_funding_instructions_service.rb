# frozen_string_literal: true

module PaymentProviderCustomers
  module Stripe
    class SyncFundingInstructionsService < BaseService
      Result = BaseResult[:funding_instructions]

      def initialize(stripe_customer)
        @stripe_customer = stripe_customer
        super
      end

      def call
        return result unless eligible_for_funding_instructions?
        funding_instructions = fetch_funding_instructions
        create_invoice_section_with_funding_info(funding_instructions)
        result
      rescue ::Stripe::StripeError => e
        result.service_failure!(code: "stripe_error", message: e.message)
      end

      private

      attr_reader :stripe_customer
      delegate :customer, to: :stripe_customer

      def create_invoice_section_with_funding_info(funding_instructions)
        section = find_or_create_invoice_section(funding_instructions)
        return unless section

        section_ids = customer.selected_invoice_custom_sections.ids | [section.id]
        Customers::ManageInvoiceCustomSectionsService.call(
          customer: customer,
          skip_invoice_custom_sections: false,
          section_ids: section_ids
        )
      end

      def find_or_create_invoice_section(funding_instructions)
        existing_section = customer.organization.system_generated_invoice_custom_sections.find_by(code: funding_instructions_code)
        return existing_section if existing_section

        formatted_details = InvoiceCustomSections::FundingInstructionsFormatterService.call(
          funding_data: funding_instructions.bank_transfer.to_hash,
          locale: preferred_locale
        ).details

        created = InvoiceCustomSections::CreateService.call(
          organization: customer.organization,
          create_params: {
            code: funding_instructions_code,
            name: "Funding Instructions",
            display_name: I18n.t("invoice.pay_with_bank_transfer", locale: preferred_locale),
            details: formatted_details,
            section_type: :system_generated
          }
        )

        created.invoice_custom_section
      end

      def fetch_funding_instructions
        ::Stripe::Customer.create_funding_instructions(
          stripe_customer.provider_customer_id,
          {
            funding_type: "bank_transfer",
            bank_transfer: funding_type_payload,
            currency: customer_currency
          },
          {api_key: stripe_api_key}
        )
      end

      def funding_type_payload
        return eu_bank_transfer_payload if customer_currency == "eur"

        {
          "usd" => {type: "us_bank_transfer"},
          "gbp" => {type: "gb_bank_transfer"},
          "jpy" => {type: "jp_bank_transfer"},
          "mxn" => {type: "mx_bank_transfer"}
        }[customer_currency]
      end

      def eu_bank_transfer_payload
        customer_country = customer.country&.upcase
        billing_entity_country = customer.billing_entity.country&.upcase

        country =
          if PaymentProviders::StripeProvider::SUPPORTED_EU_BANK_TRANSFER_COUNTRIES.include?(customer_country)
            customer_country
          elsif PaymentProviders::StripeProvider::SUPPORTED_EU_BANK_TRANSFER_COUNTRIES.include?(billing_entity_country)
            billing_entity_country
          else
            result.service_failure!(
              code: "missing_country",
              message: "No country found for customer or organization supported for EU bank transfer payload"
            ).raise_if_error!
          end

        {
          type: "eu_bank_transfer",
          eu_bank_transfer: {country: country}
        }
      end

      def customer_currency
        currency = customer.currency || customer.organization.default_currency
        currency.downcase
      end

      def funding_instructions_code
        "funding_instructions_#{customer.id}"
      end

      def preferred_locale
        customer.preferred_document_locale
      end

      def stripe_api_key
        stripe_customer.payment_provider.secret_key
      end

      def eligible_for_funding_instructions?
        stripe_customer.provider_customer_id.present? &&
          stripe_customer.provider_payment_methods&.include?("customer_balance") &&
          !customer.system_generated_invoice_custom_sections.exists?(code: "funding_instructions_#{customer.id}")
      end
    end
  end
end
