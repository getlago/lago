# frozen_string_literal: true

module PaymentProviderCustomers
  class GocardlessService < BaseService
    include Customers::PaymentProviderFinder

    def initialize(gocardless_customer = nil)
      @gocardless_customer = gocardless_customer

      super(nil)
    end

    def create
      result.gocardless_customer = gocardless_customer
      return result if gocardless_customer.provider_customer_id?

      gocardless_result = create_gocardless_customer

      gocardless_customer.update!(
        provider_customer_id: gocardless_result.id
      )

      deliver_success_webhook
      PaymentProviderCustomers::GocardlessCheckoutUrlJob.perform_later(gocardless_customer)

      result.gocardless_customer = gocardless_customer
      result
    end

    def update
      result
    end

    def generate_checkout_url(send_webhook: true)
      billing_request = create_billing_request(gocardless_customer.provider_customer_id)
      billing_request_flow = create_billing_request_flow(billing_request.id)

      result.checkout_url = billing_request_flow.authorisation_url

      if send_webhook
        SendWebhookJob.perform_later(
          "customer.checkout_url_generated",
          customer,
          checkout_url: result.checkout_url
        )
      end

      result
    end

    private

    attr_accessor :gocardless_customer

    delegate :customer, to: :gocardless_customer

    def organization
      @organization ||= customer.organization
    end

    def gocardless_payment_provider
      @gocardless_payment_provider ||= payment_provider(customer)
    end

    def client
      @client || GoCardlessPro::Client.new(
        access_token: gocardless_payment_provider.access_token,
        environment: gocardless_payment_provider.environment
      )
    end

    def create_gocardless_customer
      customer_params = {
        email: customer.email&.strip&.split(",")&.first,
        company_name: customer.name.presence,
        given_name: customer.firstname.presence,
        family_name: customer.lastname.presence
      }.compact

      client.customers.create(params: customer_params)
    rescue GoCardlessPro::Error => e
      deliver_error_webhook(e)

      raise
    end

    def deliver_success_webhook
      SendWebhookJob.perform_later(
        "customer.payment_provider_created",
        customer
      )
    end

    def deliver_error_webhook(gocardless_error)
      SendWebhookJob.perform_later(
        "customer.payment_provider_error",
        customer,
        provider_error: {
          message: gocardless_error.message,
          error_code: gocardless_error.code
        }
      )
    end

    def create_billing_request(gocardless_customer_id)
      client.billing_requests.create(
        params: {
          mandate_request: {
            scheme: "bacs"
          },
          links: {
            customer: gocardless_customer_id
          }
        }
      )
    rescue GoCardlessPro::Error => e
      deliver_error_webhook(e)

      raise
    end

    def create_billing_request_flow(billing_request_id)
      client.billing_request_flows.create(
        params: {
          redirect_uri: success_redirect_url,
          exit_uri: success_redirect_url,
          links: {
            billing_request: billing_request_id
          }
        }
      )
    rescue GoCardlessPro::Error => e
      deliver_error_webhook(e)

      raise
    end

    def success_redirect_url
      gocardless_payment_provider.success_redirect_url.presence ||
        PaymentProviders::GocardlessProvider::SUCCESS_REDIRECT_URL
    end
  end
end
