# frozen_string_literal: true

module Customers
  class CreateService < BaseService
    include Customers::PaymentProviderFinder

    Result = BaseResult[:customer]

    def initialize(**args)
      @organization = Organization.find_by(id: args[:organization_id])
      @args = args
      super
    end

    activity_loggable(
      action: "customer.created",
      record: -> { result.customer }
    )

    def call
      return result.not_found_failure!(resource: "organization") unless organization

      billing_entity = BillingEntities::ResolveService.call(
        organization:, billing_entity_code: args[:billing_entity_code]
      ).raise_if_error!.billing_entity

      billing_configuration = args[:billing_configuration]&.to_h || {}
      shipping_address = args[:shipping_address]&.to_h || {}

      unless valid_metadata_count?(metadata: args[:metadata])
        return result.single_validation_failure!(
          field: :metadata,
          error_code: "invalid_count"
        )
      end

      customer = billing_entity.customers.new(
        organization_id: organization.id,
        external_id: args[:external_id],
        name: args[:name],
        country: args[:country]&.upcase,
        address_line1: args[:address_line1],
        address_line2: args[:address_line2],
        state: args[:state],
        zipcode: args[:zipcode],
        shipping_address_line1: shipping_address[:address_line1],
        shipping_address_line2: shipping_address[:address_line2],
        shipping_country: shipping_address[:country]&.upcase,
        shipping_state: shipping_address[:state],
        shipping_zipcode: shipping_address[:zipcode],
        shipping_city: shipping_address[:city],
        email: args[:email],
        city: args[:city],
        url: args[:url],
        phone: args[:phone],
        logo_url: args[:logo_url],
        legal_name: args[:legal_name],
        legal_number: args[:legal_number],
        net_payment_term: args[:net_payment_term],
        external_salesforce_id: args[:external_salesforce_id],
        payment_provider: args[:payment_provider],
        payment_provider_code: args[:payment_provider_code],
        currency: args[:currency],
        document_locale: billing_configuration[:document_locale],
        subscription_invoice_issuing_date_anchor: billing_configuration[:subscription_invoice_issuing_date_anchor],
        subscription_invoice_issuing_date_adjustment: billing_configuration[:subscription_invoice_issuing_date_adjustment],
        tax_identification_number: args[:tax_identification_number],
        firstname: args[:firstname],
        lastname: args[:lastname],
        customer_type: args[:customer_type]
      )

      if customer&.organization&.revenue_share_enabled?
        customer.account_type = args[:account_type] if args.key?(:account_type)
        customer.exclude_from_dunning_campaign = customer.partner_account?
      end

      if args.key?(:finalize_zero_amount_invoice)
        customer.finalize_zero_amount_invoice = args[:finalize_zero_amount_invoice]
      end

      assign_premium_attributes(customer, args)

      ActiveRecord::Base.transaction do
        customer.save!

        eu_tax_code_result = Customers::EuAutoTaxesService.call(customer:, new_record: true, tax_attributes_changed: true)

        if eu_tax_code_result.success?
          args[:tax_codes] ||= []
          args[:tax_codes] = (args[:tax_codes] + [eu_tax_code_result.tax_code]).uniq
        end

        if args[:tax_codes].present?
          taxes_result = Customers::ApplyTaxesService.call(customer:, tax_codes: args[:tax_codes])
          taxes_result.raise_if_error!
        end

        args[:metadata].each { |m| create_metadata(customer:, args: m) } if args[:metadata].present?
      end

      # NOTE: handle configuration for configured payment providers
      billing_configuration = args[:provider_customer]&.to_h&.merge(
        payment_provider: args[:payment_provider],
        payment_provider_code: args[:payment_provider_code]
      )
      create_billing_configuration(customer, billing_configuration)

      result.customer = customer

      IntegrationCustomers::CreateOrUpdateBatchService.call(
        integration_customers: args[:integration_customers],
        customer: result.customer,
        new_customer: true
      )

      SendWebhookJob.perform_later("customer.created", customer)
      result
    rescue BaseService::FailedResult => e
      result.fail_with_error!(e)
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :args, :organization

    def valid_metadata_count?(metadata:)
      return true if metadata.blank?
      return true if metadata.count <= ::Metadata::CustomerMetadata::COUNT_PER_CUSTOMER

      false
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

    def create_or_update_provider_customer(customer, billing_configuration = {})
      PaymentProviders::CreateCustomerFactory.new_instance(
        provider: billing_configuration[:payment_provider] || customer.payment_provider,
        customer:,
        payment_provider_id: payment_provider(customer)&.id,
        params: billing_configuration,
        async: !(billing_configuration || {})[:sync]
      ).call.raise_if_error!
    end
  end
end
