# frozen_string_literal: true

module Customers
  # Upsert (creates or updates) a customer from an API request
  class UpsertFromApiService < BaseService
    include Customers::PaymentProviderFinder

    Result = BaseResult[:customer]

    def initialize(organization:, params:)
      @organization = organization
      @params = params
      super
    end

    def call
      billing_entity = BillingEntities::ResolveService.call(
        organization:, billing_entity_code: params[:billing_entity_code]
      ).raise_if_error!.billing_entity

      customer = organization.customers.find_or_initialize_by(external_id: params[:external_id])
      new_customer = customer.new_record?
      shipping_address = params[:shipping_address] ||= {}

      unless valid_metadata_count?(metadata: params[:metadata])
        return result.single_validation_failure!(
          field: :metadata,
          error_code: "invalid_count"
        )
      end

      unless valid_finalize_zero_amount_invoice?(params[:finalize_zero_amount_invoice])
        return result.single_validation_failure!(
          field: :finalize_zero_amount_invoice,
          error_code: "invalid_value"
        )
      end

      unless valid_integration_customers_count?(integration_customers: params[:integration_customers])
        return result.single_validation_failure!(
          field: :integration_customers,
          error_code: "invalid_count_per_integration_type"
        )
      end

      ActiveRecord::Base.transaction do
        original_tax_values = customer.slice(:tax_identification_number, :zipcode, :country).symbolize_keys

        billing_entity_changed = false
        if new_customer || (params.key?(:billing_entity_code) && allow_billing_entity_update?(customer))
          customer.billing_entity = billing_entity
          billing_entity_changed = !new_customer && customer.billing_entity_id_changed?
        end
        customer.name = params[:name] if params.key?(:name)
        customer.country = params[:country]&.upcase if params.key?(:country)
        customer.address_line1 = params[:address_line1] if params.key?(:address_line1)
        customer.address_line2 = params[:address_line2] if params.key?(:address_line2)
        customer.state = params[:state] if params.key?(:state)
        customer.zipcode = params[:zipcode] if params.key?(:zipcode)
        customer.email = params[:email] if params.key?(:email)
        customer.city = params[:city] if params.key?(:city)
        customer.shipping_address_line1 = shipping_address[:address_line1] if shipping_address.key?(:address_line1)
        customer.shipping_address_line2 = shipping_address[:address_line2] if shipping_address.key?(:address_line2)
        customer.shipping_city = shipping_address[:city] if shipping_address.key?(:city)
        customer.shipping_zipcode = shipping_address[:zipcode] if shipping_address.key?(:zipcode)
        customer.shipping_state = shipping_address[:state] if shipping_address.key?(:state)
        customer.shipping_country = shipping_address[:country]&.upcase if shipping_address.key?(:country)
        customer.url = params[:url] if params.key?(:url)
        customer.phone = params[:phone] if params.key?(:phone)
        customer.logo_url = params[:logo_url] if params.key?(:logo_url)
        customer.legal_name = params[:legal_name] if params.key?(:legal_name)
        customer.legal_number = params[:legal_number] if params.key?(:legal_number)
        customer.net_payment_term = params[:net_payment_term] if params.key?(:net_payment_term)
        customer.external_salesforce_id = params[:external_salesforce_id] if params.key?(:external_salesforce_id)
        customer.finalize_zero_amount_invoice = params[:finalize_zero_amount_invoice] || "inherit" if params.key?(:finalize_zero_amount_invoice)
        customer.firstname = params[:firstname] if params.key?(:firstname)
        customer.lastname = params[:lastname] if params.key?(:lastname)
        customer.customer_type = params[:customer_type] if params.key?(:customer_type)

        if customer.organization.revenue_share_enabled? && customer.editable?
          customer.account_type = params[:account_type] if params.key?(:account_type)
          customer.exclude_from_dunning_campaign = customer.partner_account?
        end

        if params.key?(:tax_identification_number)
          customer.tax_identification_number = params[:tax_identification_number]
        end

        assign_premium_attributes(customer, params)
        address_changed = !new_customer && customer.address_changed?

        if params.key?(:currency)
          Customers::UpdateCurrencyService
            .call(customer:, currency: params[:currency], customer_update: true)
            .raise_if_error!
        end

        customer.save!
        customer.error_details.tax_error.delete_all if address_changed

        tax_attributes_changed = original_tax_values.any? { |key, value| params.key?(key) && params[key] != value }

        eu_tax_code_result = Customers::EuAutoTaxesService.call(
          customer:,
          new_record: new_customer,
          tax_attributes_changed: tax_attributes_changed || billing_entity_changed
        )

        if eu_tax_code_result.success?
          params[:tax_codes] ||= []
          params[:tax_codes] = (params[:tax_codes] + [eu_tax_code_result.tax_code]).uniq
        end

        # NOTE: EU-managed taxes (lago_eu_*) belong to the previous billing entity. When the
        #       billing entity changes and no new EU tax applies (new entity does not manage
        #       EU taxes, or a VIES check is still pending), reset them so the customer falls
        #       back to the new billing entity's taxes.
        if billing_entity_changed && !params.key?(:tax_codes)
          params[:tax_codes] = customer.taxes.where.not("code ILIKE ?", "lago_eu%").pluck(:code)
        end

        if params.key?(:tax_codes)
          taxes_result = Customers::ApplyTaxesService.call(customer:, tax_codes: params[:tax_codes])
          taxes_result.raise_if_error!
        end

        Customers::ManageInvoiceCustomSectionsService.call(
          customer:,
          skip_invoice_custom_sections: params[:skip_invoice_custom_sections],
          section_codes: params[:invoice_custom_section_codes]
        ).raise_if_error!

        if new_customer && params[:metadata]
          params[:metadata].each { |m| create_metadata(customer:, args: m) }
        elsif params[:metadata]
          Customers::Metadata::UpdateService.call(customer:, params: params[:metadata])
        end
      end

      # NOTE: handle configuration for configured payment providers
      handle_api_billing_configuration(customer, new_customer)

      result.customer = customer.reload

      IntegrationCustomers::CreateOrUpdateBatchService.call(
        integration_customers: params[:integration_customers],
        customer: result.customer,
        new_customer:
      )

      if new_customer
        SendWebhookJob.perform_later("customer.created", customer)
        Utils::ActivityLog.produce_after_commit(customer, "customer.created")
      else
        SendWebhookJob.perform_later("customer.updated", customer)
        Utils::ActivityLog.produce_after_commit(customer, "customer.updated")
      end

      result
    rescue BaseService::ServiceFailure => e
      result.single_validation_failure!(error_code: e.code)
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      result.fail_with_error!(e)
    rescue ActiveRecord::RecordNotUnique
      result.single_validation_failure!(field: :external_id, error_code: "value_already_exist")
    end

    private

    attr_reader :organization, :params

    def valid_finalize_zero_amount_invoice?(value)
      return true if value.nil?
      Customer::FINALIZE_ZERO_AMOUNT_INVOICE_OPTIONS.include?(value.to_sym)
    end

    def valid_metadata_count?(metadata:)
      return true if metadata.blank?
      return true if metadata.count <= ::Metadata::CustomerMetadata::COUNT_PER_CUSTOMER

      false
    end

    def valid_integration_customers_count?(integration_customers:)
      return true if integration_customers.blank?

      input_types = integration_customers&.map { |c| c.to_h.deep_symbolize_keys }&.map { |c| c[:integration_type] }

      input_types.length == input_types.uniq.length
    end

    def allow_billing_entity_update?(customer)
      organization.feature_flag_enabled?(:multi_entity_billing) || customer.editable?
    end

    def create_metadata(customer:, args:)
      customer.metadata.create!(
        organization_id: organization.id,
        key: args[:key],
        value: args[:value],
        display_in_invoice: args[:display_in_invoice] || false
      )
    end

    def assign_premium_attributes(customer, args)
      return unless License.premium?

      customer.timezone = args[:timezone] if args.key?(:timezone)
      customer.invoice_grace_period = args[:invoice_grace_period] if args.key?(:invoice_grace_period)
    end

    def create_billing_configuration(customer, billing_configuration = {})
      return if billing_configuration.blank? || (api_context? && billing_configuration[:payment_provider].nil?)

      create_provider_customer = billing_configuration[:sync_with_provider]
      create_provider_customer ||= billing_configuration[:provider_customer_id]
      return unless create_provider_customer

      if api_context?
        customer.payment_provider = billing_configuration[:payment_provider]

        payment_provider_result = PaymentProviders::FindService.new(
          organization_id: customer.organization_id,
          code: billing_configuration[:payment_provider_code].presence,
          payment_provider_type: customer.payment_provider
        ).call
        payment_provider_result.raise_if_error!

        customer.payment_provider_code = payment_provider_result.payment_provider.code
        customer.save!
      end

      create_or_update_provider_customer(customer, billing_configuration)
    end

    def handle_api_billing_configuration(customer, new_customer)
      params[:billing_configuration] = {} unless params.key?(:billing_configuration)

      billing = params[:billing_configuration]

      Customers::UpdateInvoiceIssuingDateSettingsService.call(customer:, params:)

      customer.document_locale = billing[:document_locale] if billing.key?(:document_locale)

      if new_customer || should_create_billing_configuration?(billing, customer)
        create_billing_configuration(customer, billing)
        customer.save!
        return
      end

      old_provider_customer = customer.provider_customer
      old_payment_provider = customer.payment_provider
      payment_provider_result = PaymentProviders::FindService.new(
        organization_id: customer.organization_id,
        code: customer.payment_provider_code,
        payment_provider_type: old_payment_provider
      ).call
      old_payment_provider_id = payment_provider_result.payment_provider&.id

      if billing.key?(:payment_provider)
        customer.payment_provider = nil
        if Customer::PAYMENT_PROVIDERS.include?(billing[:payment_provider])
          customer.payment_provider = billing[:payment_provider]
          customer.payment_provider_code = billing[:payment_provider_code] if billing.key?(:payment_provider_code)
        end
      end

      customer.save!

      if old_provider_customer && billing.key?(:payment_provider) && billing[:payment_provider].nil?
        discard_payment_methods(old_provider_customer.payment_methods)
      end

      return if customer.payment_provider.nil?

      update_provider_customer = (billing || {})[:provider_customer_id].present?
      update_provider_customer ||= customer.provider_customer&.provider_customer_id.present?

      return unless update_provider_customer

      create_or_update_provider_customer(customer, billing)

      if customer.provider_customer&.provider_customer_id
        PaymentProviderCustomers::UpdateService.call(customer)
      end

      if old_provider_customer
        new_payment_provider_id = payment_provider(customer)&.id

        if old_payment_provider != customer.payment_provider
          discard_payment_methods(old_provider_customer.payment_methods)
        elsif old_payment_provider_id.present? &&
            new_payment_provider_id.present? &&
            old_payment_provider_id != new_payment_provider_id
          discard_payment_methods(old_provider_customer.payment_methods)
        end
      end
    end

    def create_or_update_provider_customer(customer, billing_configuration = {})
      PaymentProviders::CreateCustomerFactory.new_instance(
        provider: billing_configuration[:payment_provider] || customer.payment_provider,
        customer:,
        payment_provider_id: payment_provider(customer)&.id,
        params: billing_configuration,
        async: !(billing_configuration || {})[:sync]
      ).call.raise_if_error!
    end

    def discard_payment_methods(payment_methods)
      payment_methods.find_each do |payment_method|
        PaymentMethods::DestroyService.call(payment_method:)
      end
    end

    def should_create_billing_configuration?(billing, customer)
      (billing[:sync_with_provider] || billing[:provider_customer_id].present?) && customer.provider_customer&.provider_customer_id.nil?
    end
  end
end
