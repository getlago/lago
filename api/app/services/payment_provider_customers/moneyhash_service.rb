# frozen_string_literal: true

module PaymentProviderCustomers
  class MoneyhashService < BaseService
    include Customers::PaymentProviderFinder

    def initialize(moneyhash_customer = nil)
      @moneyhash_customer = moneyhash_customer

      super(nil)
    end

    def create
      result.moneyhash_customer = moneyhash_customer
      return result if moneyhash_customer.provider_customer_id?
      moneyhash_result = create_moneyhash_customer

      return result if !result.success?

      provider_customer_id = begin
        moneyhash_result["data"]["id"]
      rescue
        ""
      end

      moneyhash_customer.update!(
        provider_customer_id: provider_customer_id
      )
      deliver_success_webhook
      result.moneyhash_customer = moneyhash_customer
      checkout_url_result = generate_checkout_url
      return result unless checkout_url_result.success?
      result.checkout_url = checkout_url_result.checkout_url
      result
    end

    def update
      result
    end

    def generate_checkout_url(send_webhook: true)
      return result.not_found_failure!(resource: "moneyhash_payment_provider") unless moneyhash_payment_provider
      return result.not_found_failure!(resource: "moneyhash_customer") unless moneyhash_customer

      response = checkout_url_client.post_with_response(checkout_url_params, headers)
      moneyhash_result = JSON.parse(response.body)

      return result unless moneyhash_result

      result.checkout_url = "#{moneyhash_result["data"]["embed_url"]}?lago_request=generate_checkout_url"

      if send_webhook
        SendWebhookJob.perform_now(
          "customer.checkout_url_generated",
          customer,
          checkout_url: result.checkout_url
        )
      end
      result
    rescue LagoHttpClient::HttpError => e
      deliver_error_webhook(e)
      result.service_failure!(code: e.error_code, message: e.message)
    end

    def update_payment_method(organization_id:, customer_id:, payment_method_id:, metadata: {}, card_details: {})
      moneyhash_customer = PaymentProviderCustomers::MoneyhashCustomer.find_by(customer_id: customer_id)
      return handle_missing_customer(organization_id, metadata) unless moneyhash_customer

      moneyhash_customer.payment_method_id = payment_method_id
      moneyhash_customer.save!

      find_or_create_result = PaymentMethods::FindOrCreateFromProviderService.call(
        customer: moneyhash_customer.customer,
        payment_provider_customer: moneyhash_customer,
        provider_method_id: payment_method_id,
        params: {provider_payment_methods: ["card"]},
        set_as_default: true
      )
      result.payment_method = find_or_create_result.payment_method

      if card_details.present? && result.payment_method.present?
        PaymentMethods::UpdateDetailsService.call(
          payment_method: result.payment_method,
          insert: card_details
        )
      end

      result.moneyhash_customer = moneyhash_customer
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    def delete_payment_method(organization_id:, customer_id:, payment_method_id:, metadata: {})
      moneyhash_customer = PaymentProviderCustomers::MoneyhashCustomer.find_by(customer_id: customer_id)
      return handle_missing_customer(organization_id, metadata) unless moneyhash_customer

      if moneyhash_customer.payment_method_id == payment_method_id
        moneyhash_customer.payment_method_id = nil
        moneyhash_customer.save!
      end

      payment_method = moneyhash_customer.customer.payment_methods.find_by(provider_method_id: payment_method_id)
      PaymentMethods::DestroyService.call(payment_method:) if payment_method

      result.moneyhash_customer = moneyhash_customer
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_accessor :moneyhash_customer

    delegate :customer, to: :moneyhash_customer

    def customers_client
      @customers_client || LagoHttpClient::Client.new("#{PaymentProviders::MoneyhashProvider.api_base_url}/api/v1.1/customers/")
    end

    def checkout_url_client
      @checkout_url_client || LagoHttpClient::Client.new("#{::PaymentProviders::MoneyhashProvider.api_base_url}/api/v1.1/payments/intent/")
    end

    def api_key
      moneyhash_payment_provider.secret_key
    end

    def moneyhash_payment_provider
      @moneyhash_payment_provider ||= payment_provider(customer)
    end

    def create_moneyhash_customer
      customer_params = {
        type: customer&.customer_type&.upcase,
        first_name: customer&.firstname,
        last_name: customer&.lastname,
        email: customer&.email,
        phone_number: customer&.phone,
        tax_id: customer&.tax_identification_number&.to_i&.to_s,
        address: [customer&.address_line1, customer&.address_line2].compact.join(" "),
        contact_person_name: (customer&.name.presence || [customer&.firstname, customer&.lastname].compact.join(" ")).presence,
        company_name: customer&.legal_name,
        custom_fields: {
          # service
          lago_mh_service: "PaymentProviderCustomers::MoneyhashService",
          # request
          lago_request: "create_moneyhash_customer"
        }
      }.compact

      customer_params[:custom_fields].merge!(moneyhash_customer.mh_custom_fields)

      response = customers_client.post_with_response(customer_params, headers)
      JSON.parse(response.body)
    rescue LagoHttpClient::HttpError => e
      deliver_error_webhook(e)
      nil
    end

    def deliver_error_webhook(moneyhash_error)
      SendWebhookJob.perform_later(
        "customer.payment_provider_error",
        customer,
        provider_error: {
          message: moneyhash_error.message,
          error_code: moneyhash_error.error_code
        }
      )
    end

    def deliver_success_webhook
      SendWebhookJob.perform_later(
        "customer.payment_provider_created",
        customer
      )
    end

    def headers
      {
        "Content-Type" => "application/json",
        "x-Api-Key" => moneyhash_payment_provider.api_key
      }
    end

    def checkout_url_params
      params = {
        amount: 5.0,
        amount_currency: customer.currency.presence || customer.organization_default_currency,
        flow_id: moneyhash_payment_provider.flow_id,
        billing_data: moneyhash_customer.mh_billing_data,
        customer: moneyhash_customer.provider_customer_id,
        webhook_url: moneyhash_payment_provider.webhook_end_point,
        merchant_initiated: false,
        tokenize_card: true,
        payment_type: "UNSCHEDULED",
        recurring_data: {
          agreement_id: moneyhash_customer.customer_id
        },
        custom_fields: {
          # mit flag
          lago_mit: false,
          # service
          lago_mh_service: "PaymentProviderCustomers::MoneyhashService",
          # request
          lago_request: "generate_checkout_url"
        }
      }

      params[:custom_fields].merge!(moneyhash_customer.mh_custom_fields)

      params
    end

    def handle_missing_customer(organization_id, metadata)
      # NOTE: this is a silent failure, we return result directly if lago_customer_id is not present or Customer is not found
      return result unless metadata&.key?("lago_customer_id")
      return result if Customer.find_by(id: metadata["lago_customer_id"], organization_id:).nil?

      # fail only when certain that moneyhash customer is not found (after finding the customer)
      result.not_found_failure!(resource: "moneyhash_customer")
    end
  end
end
