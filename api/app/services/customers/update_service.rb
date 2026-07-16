# frozen_string_literal: true

module Customers
  class UpdateService < BaseService
    extend Forwardable
    include Customers::PaymentProviderFinder

    Result = BaseResult[:customer]

    def initialize(customer:, args:)
      @customer = customer
      @args = args

      super
    end

    activity_loggable(
      action: "customer.updated",
      record: -> { customer }
    )

    def call
      return result.not_found_failure!(resource: "customer") unless customer

      unless valid_metadata_count?(metadata: args[:metadata])
        return result.single_validation_failure!(
          field: :metadata,
          error_code: "invalid_count"
        )
      end

      old_payment_provider = customer.payment_provider
      old_provider_customer = customer.provider_customer
      original_tax_values = customer.slice(:tax_identification_number, :zipcode, :country).symbolize_keys
      ActiveRecord::Base.transaction do
        billing_configuration = args[:billing_configuration]&.to_h || {}
        shipping_address = args[:shipping_address]&.to_h || {}

        if args.key?(:currency)
          Customers::UpdateCurrencyService
            .call(customer:, currency: args[:currency], customer_update: true)
            .raise_if_error!
        end

        customer.name = args[:name] if args.key?(:name)
        customer.tax_identification_number = args[:tax_identification_number] if args.key?(:tax_identification_number)
        customer.country = args[:country]&.upcase if args.key?(:country)
        customer.address_line1 = args[:address_line1] if args.key?(:address_line1)
        customer.address_line2 = args[:address_line2] if args.key?(:address_line2)
        customer.state = args[:state] if args.key?(:state)
        customer.zipcode = args[:zipcode] if args.key?(:zipcode)
        customer.email = args[:email] if args.key?(:email)
        customer.city = args[:city] if args.key?(:city)
        customer.url = args[:url] if args.key?(:url)
        customer.phone = args[:phone] if args.key?(:phone)
        customer.logo_url = args[:logo_url] if args.key?(:logo_url)
        customer.legal_name = args[:legal_name] if args.key?(:legal_name)
        customer.legal_number = args[:legal_number] if args.key?(:legal_number)
        customer.external_salesforce_id = args[:external_salesforce_id] if args.key?(:external_salesforce_id)
        customer.shipping_address_line1 = shipping_address[:address_line1] if shipping_address.key?(:address_line1)
        customer.shipping_address_line2 = shipping_address[:address_line2] if shipping_address.key?(:address_line2)
        customer.shipping_city = shipping_address[:city] if shipping_address.key?(:city)
        customer.shipping_zipcode = shipping_address[:zipcode] if shipping_address.key?(:zipcode)
        customer.shipping_state = shipping_address[:state] if shipping_address.key?(:state)
        customer.shipping_country = shipping_address[:country]&.upcase if shipping_address.key?(:country)
        customer.firstname = args[:firstname] if args.key?(:firstname)
        customer.lastname = args[:lastname] if args.key?(:lastname)
        customer.customer_type = args[:customer_type] if args.key?(:customer_type)

        if args.key?(:finalize_zero_amount_invoice)
          customer.finalize_zero_amount_invoice = args[:finalize_zero_amount_invoice]
        end

        assign_premium_attributes(customer, args)

        customer.payment_provider = args[:payment_provider] if args.key?(:payment_provider)
        customer.payment_provider_code = args[:payment_provider_code] if args.key?(:payment_provider_code)
        customer.invoice_footer = args[:invoice_footer] if args.key?(:invoice_footer)

        if billing_configuration.key?(:document_locale)
          customer.document_locale = billing_configuration[:document_locale]
        end

        @address_changed = customer.address_changed?
      end

      if args.key?(:billing_configuration)
        billing = args[:billing_configuration]
        customer.invoice_footer = billing[:invoice_footer] if billing.key?(:invoice_footer)
      end

      Customers::UpdateInvoiceIssuingDateSettingsService.call(customer:, params: args)

      if args.key?(:net_payment_term)
        Customers::UpdateInvoicePaymentDueDateService.call(customer:, net_payment_term: args[:net_payment_term])
      end

      # NOTE: Some fields are not editable if customer is attached to subscriptions:
      #       external_id,
      #       account_type,
      #       billing_entity_id (gated by editable? unless multi_entity_billing flag is enabled)
      billing_entity_changed = false
      if args.key?(:billing_entity_code) && allow_billing_entity_update?
        customer.billing_entity = billing_entity
        billing_entity_changed = customer.billing_entity_id_changed?
      end

      if customer.editable?
        customer.external_id = args[:external_id] if args.key?(:external_id)

        if organization.revenue_share_enabled?
          customer.account_type = args[:account_type] if args.key?(:account_type)
        end
      end

      if organization.auto_dunning_enabled?
        if args.key?(:applied_dunning_campaign_id)
          customer.applied_dunning_campaign = applied_dunning_campaign
          customer.exclude_from_dunning_campaign = false
        end

        # NOTE: exclude_from_dunning_campaign has higher priority than applied campaign
        if args.key?(:exclude_from_dunning_campaign)
          customer.exclude_from_dunning_campaign = args[:exclude_from_dunning_campaign]
          customer.applied_dunning_campaign = nil if args[:exclude_from_dunning_campaign]
        end
      end

      # NOTE: partner accounts are excluded from dunning campaigns
      if customer.partner_account?
        customer.exclude_from_dunning_campaign = true
        customer.applied_dunning_campaign = nil
      end

      ActiveRecord::Base.transaction do
        if old_provider_customer && args[:payment_provider].nil? && args[:payment_provider_code].present?
          old_provider_customer.discard!
          customer.payment_provider_code = nil
        end

        if customer.applied_dunning_campaign_id_changed? || customer.exclude_from_dunning_campaign_changed?
          customer.reset_dunning_campaign!
        end

        Customers::ManageInvoiceCustomSectionsService.call(
          customer:,
          skip_invoice_custom_sections: args[:skip_invoice_custom_sections],
          section_ids: args[:configurable_invoice_custom_section_ids]
        ).raise_if_error!

        customer.save!
        customer.error_details.tax_error.delete_all if @address_changed
        customer.reload

        tax_attributes_changed = original_tax_values.any? { |key, value| args.key?(key) && args[key] != value }

        eu_tax_code_result = Customers::EuAutoTaxesService.call(
          customer:,
          new_record: false,
          tax_attributes_changed: tax_attributes_changed || billing_entity_changed
        )

        if eu_tax_code_result.success?
          args[:tax_codes] ||= []
          args[:tax_codes] = (args[:tax_codes] + [eu_tax_code_result.tax_code]).uniq
        end

        # NOTE: EU-managed taxes (lago_eu_*) belong to the previous billing entity. When the
        #       billing entity changes and no new EU tax applies (new entity does not manage
        #       EU taxes, or a VIES check is still pending), reset them so the customer falls
        #       back to the new billing entity's taxes.
        if billing_entity_changed && args[:tax_codes].nil?
          args[:tax_codes] = customer.taxes.where.not("code ILIKE ?", "lago_eu%").pluck(:code)
        end

        if args[:tax_codes]
          taxes_result = Customers::ApplyTaxesService.call(customer:, tax_codes: args[:tax_codes])
          taxes_result.raise_if_error!
        end
        Customers::Metadata::UpdateService.call(customer:, params: args[:metadata]) if args[:metadata]
      end

      # NOTE: if payment provider is updated, we need to create/update the provider customer
      if args.key?(:provider_customer) || args.key?(:payment_provider)
        payment_provider = old_payment_provider || customer.payment_provider
        create_or_update_provider_customer(customer, payment_provider, args[:provider_customer])
      end

      if args.dig(:provider_customer, :provider_customer_id)
        update_result = PaymentProviderCustomers::UpdateService.call(customer)
        update_result.raise_if_error!
      end

      result.customer = customer

      if old_provider_customer && args.key?(:payment_provider) && args[:payment_provider].nil?
        old_provider_customer.payment_methods.find_each do |payment_method|
          PaymentMethods::DestroyService.call(payment_method:)
        end
      end

      IntegrationCustomers::CreateOrUpdateBatchService.call(
        integration_customers: args[:integration_customers],
        customer: result.customer,
        new_customer: false
      )
      SendWebhookJob.perform_later("customer.updated", customer)
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue ActiveRecord::RecordNotFound => e
      result.not_found_failure!(resource: e.model.underscore)
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :customer, :args
    def_delegators :customer, :organization

    def billing_entity
      @billing_entity ||= organization.billing_entities.find_by!(code: args[:billing_entity_code])
    end

    def valid_metadata_count?(metadata:)
      return true if metadata.blank?
      return true if metadata.count <= ::Metadata::CustomerMetadata::COUNT_PER_CUSTOMER

      false
    end

    def allow_billing_entity_update?
      organization.feature_flag_enabled?(:multi_entity_billing) || customer.editable?
    end

    def assign_premium_attributes(customer, args)
      return unless License.premium?

      customer.timezone = args[:timezone] if args.key?(:timezone)
    end

    def create_or_update_provider_customer(customer, payment_provider, billing_configuration = {})
      return if payment_provider.nil?

      handle_provider_customer = customer.payment_provider.present?
      handle_provider_customer ||= (billing_configuration || {})[:provider_customer_id].present?
      handle_provider_customer ||= customer.send(:"#{payment_provider}_customer")&.provider_customer_id.present?
      return unless handle_provider_customer

      PaymentProviders::CreateCustomerFactory.new_instance(
        provider: payment_provider,
        customer:,
        payment_provider_id: payment_provider(customer)&.id,
        params: billing_configuration
      ).call.raise_if_error!

      # NOTE: Create service is modifying an other instance of the provider customer
      customer.reload
    end

    def applied_dunning_campaign
      return customer.applied_dunning_campaign unless args.key?(:applied_dunning_campaign_id)
      return unless args[:applied_dunning_campaign_id]

      DunningCampaign.find(args[:applied_dunning_campaign_id])
    end
  end
end
