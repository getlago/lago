# frozen_string_literal: true

require "rails_helper"

describe "Invoice Payments Scenarios" do
  let(:webhook_url) { "https://test.co/lago" }
  let(:organization) do
    create(:organization,
      name: "JC AI",
      premium_integrations: %w[auto_dunning],
      email_settings: [],
      webhook_url:)
  end

  let(:external_subscription_id) { "sub_payment-failed" }
  let(:plan) { create(:plan, organization:, pay_in_advance: true, amount_cents: 149_00) }

  let(:webhooks_sent) { [] }

  let(:customer) { create(:customer, organization:, net_payment_term: 2) }

  include_context "with Stripe configured for customer"

  before do
    stub_pdf_generation

    stub_request(:post, webhook_url).with do |req|
      webhooks_sent << JSON.parse(req.body.dup)
      true
    end.and_return(status: 200)

    stub_request(:post, "https://api.stripe.com/v1/payment_intents")
      .and_return(
        status: 402,
        body: get_stripe_fixtures("payment_intent_card_declined_response.json")
      )
  end

  it "retries overdue invoices" do
    travel_to(DateTime.new(2025, 1, 1, 10)) do
      create_subscription(
        {
          external_customer_id: customer.external_id,
          external_id: external_subscription_id,
          plan_code: plan.code
        }
      )
      perform_billing

      payment_failure_webhook = webhooks_sent.find { it["webhook_type"] == "invoice.payment_failure" }

      expect(payment_failure_webhook["payment_provider_invoice_payment_error"]["error_details"]).to include({
        "code" => "card_declined",
        "message" => "Your card was declined."
      })
    end
  end
end
