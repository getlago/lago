# frozen_string_literal: true

RSpec.shared_context "with Stripe configured for customer" do
  let(:stripe_cus_id) { "cus_123456789" }
  let(:stripe_pm_id) { "pm_123456" }

  let(:stripe_provider) { create(:stripe_provider, organization:) }
  let(:stripe_customer) { create(:stripe_customer, customer:, payment_provider: stripe_provider, provider_customer_id: stripe_cus_id) }

  let(:stripe_customer_response) do
    get_stripe_fixtures("customer_retrieve_response.json") do |h|
      h["invoice_settings"]["default_payment_method"] = stripe_pm_id
    end
  end
  let(:stripe_payment_method_response) do
    get_stripe_fixtures("retrieve_payment_method_response.json") do |h|
      h["id"] = stripe_pm_id
      h["customer"] = stripe_cus_id
    end
  end

  before do
    customer.update! payment_provider: :stripe, payment_provider_code: stripe_provider.code
    stripe_customer

    create(:payment_method, payment_provider_customer: stripe_customer, provider_method_id: stripe_pm_id, is_default: true)

    stub_request(:get, "https://api.stripe.com/v1/customers/#{stripe_cus_id}")
      .and_return(status: 200, body: stripe_customer_response)
    stub_request(:get, "https://api.stripe.com/v1/customers/#{stripe_cus_id}/payment_methods/#{stripe_pm_id}")
      .and_return(status: 200, body: stripe_payment_method_response)

    WebMock.after_request do |request_signature, response|
      if request_signature.uri.path.match?(%r{/v1/payment_intents})
        request_body_hash = if request_signature.url_encoded?
          Rack::Utils.parse_nested_query(request_signature.body)
        elsif request_signature.body.json_encoded?
          JSON.parse(request_signature.body)
        end

        Jobs::MockStripeWebhookEventJob.perform_later(
          organization,
          request_body_hash,
          JSON.parse(response.body)
        )
      end
    end
  end
end
