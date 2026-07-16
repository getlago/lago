# frozen_string_literal: true

module PaymentProviderCustomers
  class StripeService < BaseService
    include Customers::PaymentProviderFinder

    def initialize(stripe_customer = nil)
      @stripe_customer = stripe_customer

      super(nil)
    end

    def create
      return result unless customer

      result.stripe_customer = stripe_customer
      return result if stripe_customer.provider_customer_id? || !stripe_payment_provider

      stripe_result = create_stripe_customer
      return result if !stripe_result || !result.success?

      stripe_customer.update!(
        provider_customer_id: stripe_result.id
      )

      deliver_success_webhook
      sync_funding_instructions
      if payment_methods_require_setup?
        PaymentProviderCustomers::StripeCheckoutUrlJob.perform_after_commit(stripe_customer)
      end

      result.stripe_customer = stripe_customer
      result
    end

    def update
      return result if !stripe_payment_provider || stripe_customer.provider_customer_id.blank?

      ::Stripe::Customer.update(stripe_customer.provider_customer_id, stripe_update_payload, {api_key:})
      sync_funding_instructions
      result
    rescue ::Stripe::InvalidRequestError, ::Stripe::PermissionError => e
      deliver_error_webhook(e)

      result.third_party_failure!(third_party: "Stripe", error_code: e.code, error_message: e.message)
    rescue ::Stripe::AuthenticationError => e
      deliver_error_webhook(e)

      message = ["Stripe authentication failed.", e.message.presence].compact.join(" ")
      result.unauthorized_failure!(message:)
    end

    def delete_payment_method(organization_id:, stripe_customer_id:, payment_method_id:, metadata: {})
      @stripe_customer = PaymentProviderCustomers::StripeCustomer
        .joins(:customer)
        .where(customers: {organization_id:})
        .find_by(provider_customer_id: stripe_customer_id)
      return handle_missing_customer(organization_id, metadata) unless stripe_customer

      # NOTE: check if payment_method was the default one
      stripe_customer.payment_method_id = nil if stripe_customer.payment_method_id == payment_method_id

      payment_method = customer.payment_methods.find_by(provider_method_id: payment_method_id)
      if payment_method
        destroy_result = PaymentMethods::DestroyService.call(payment_method:)
        result.payment_method = destroy_result.payment_method
      end

      result.stripe_customer = stripe_customer
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    def generate_checkout_url(send_webhook: true)
      return result unless customer # NOTE: Customer is nil when deleted.
      return result if customer.organization.webhook_endpoints.none? && send_webhook && payment_provider(customer)

      unless payment_methods_require_setup?
        return result.single_validation_failure!(
          field: :provider_payment_methods,
          error_code: "no_payment_methods_to_setup_available"
        )
      end

      res = ::Stripe::Checkout::Session.create(checkout_link_params, {api_key:})

      result.checkout_url = res["url"]

      if send_webhook
        SendWebhookJob.perform_later("customer.checkout_url_generated", customer, checkout_url: result.checkout_url)
      end

      result
    rescue ::Stripe::InvalidRequestError, ::Stripe::PermissionError => e
      deliver_error_webhook(e)
      result.third_party_failure!(third_party: "Stripe", error_code: e.code, error_message: e.message)
    rescue ::Stripe::AuthenticationError => e
      deliver_error_webhook(e)

      message = ["Stripe authentication failed.", e.message.presence].compact.join(" ")
      result.unauthorized_failure!(message:)
    end

    private

    attr_accessor :stripe_customer

    delegate :customer, to: :stripe_customer

    def payment_methods_require_setup?
      stripe_customer.provider_payment_methods_require_setup?
    end

    def organization
      customer.organization
    end

    def api_key
      stripe_payment_provider.secret_key
    end

    def name
      customer.name.presence || [customer.firstname, customer.lastname].compact.join(" ")
    end

    def checkout_link_params
      {
        success_url: success_redirect_url,
        mode: "setup",
        payment_method_types: stripe_customer.provider_payment_methods_with_setup,
        customer: stripe_customer.provider_customer_id
      }
    end

    def success_redirect_url
      stripe_payment_provider.success_redirect_url.presence ||
        PaymentProviders::StripeProvider::SUCCESS_REDIRECT_URL
    end

    def create_stripe_customer
      ::Stripe::Customer.create(
        stripe_create_payload,
        {
          api_key:,
          idempotency_key: [customer.id, customer.updated_at.to_i].join("-")
        }
      )
    rescue ::Stripe::InvalidRequestError, ::Stripe::PermissionError => e
      deliver_error_webhook(e)
      nil
    rescue ::Stripe::AuthenticationError => e
      deliver_error_webhook(e)

      message = ["Stripe authentication failed.", e.message.presence].compact.join(" ")
      result.unauthorized_failure!(message:)
    rescue ::Stripe::IdempotencyError
      stripe_customers = ::Stripe::Customer.list({email: customer.email}, {api_key:})
      return stripe_customers.first if stripe_customers.count == 1

      # NOTE: Multiple stripe customers with the same email,
      #       re-raise to fix the issue
      raise
    end

    def stripe_create_payload
      {
        address: {
          city: customer.city,
          country: customer.country,
          line1: customer.address_line1,
          line2: customer.address_line2,
          postal_code: customer.zipcode,
          state: customer.state
        },
        email: customer.email&.strip&.split(",")&.first,
        name:,
        metadata: {
          lago_customer_id: customer.id,
          customer_id: customer.external_id
        },
        phone: customer.phone
      }
    end

    def stripe_update_payload
      {
        address: {
          city: customer.city,
          country: customer.country,
          line1: customer.address_line1,
          line2: customer.address_line2,
          postal_code: customer.zipcode,
          state: customer.state
        },
        email: customer.email&.strip&.split(",")&.first,
        name:,
        phone: customer.phone
      }
    end

    def deliver_success_webhook
      SendWebhookJob.perform_later(
        "customer.payment_provider_created",
        customer
      )
    end

    def deliver_error_webhook(stripe_error)
      SendWebhookJob.perform_later(
        "customer.payment_provider_error",
        customer,
        provider_error: {
          message: stripe_error.message,
          error_code: stripe_error.code
        }
      )
    end

    def handle_missing_customer(organization_id, metadata)
      # NOTE: Stripe customer was not created from lago
      return result unless metadata&.key?(:lago_customer_id)

      # NOTE: Customer does not belong to this lago instance or
      #       exists but does not belong to the organizations
      #       (Happens when the Stripe API key is shared between organizations)
      return result if Customer.find_by(id: metadata[:lago_customer_id], organization_id:).nil?

      result.not_found_failure!(resource: "stripe_customer")
    end

    def sync_funding_instructions
      return if stripe_customer.provider_customer_id.blank?
      return unless stripe_customer.provider_payment_methods&.include?("customer_balance")

      PaymentProviderCustomers::StripeSyncFundingInstructionsJob.perform_later(stripe_customer)
    end

    def stripe_payment_provider
      @stripe_payment_provider ||= payment_provider(customer)
    end
  end
end
