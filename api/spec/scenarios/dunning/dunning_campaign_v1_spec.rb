# frozen_string_literal: true

require "rails_helper"

describe "Dunning Campaign v1", :premium do
  let(:organization) do
    create(:organization, name: "JC AI", premium_integrations: %w[auto_dunning])
  end

  let(:billing_entity) do
    create(:billing_entity, organization:, name: "ACME Corp", email_settings: [], applied_dunning_campaign: dunning_campaign)
  end

  let(:dunning_campaign) do
    create(:dunning_campaign, organization:,
      max_attempts: 2, days_between_attempts: 2)
  end
  let(:dunning_campaign_threshold) do
    create(:dunning_campaign_threshold, dunning_campaign:, amount_cents: 150_00, currency: "EUR")
  end
  let(:stripe_cus_id) { "cus_123456789" }
  let(:stripe_pm_id) { "pm_123456" }

  let(:stripe_provider) { create(:stripe_provider, organization:) }

  let(:customer) do
    create(
      :customer,
      organization:,
      billing_entity:,
      payment_provider: :stripe,
      payment_provider_code: stripe_provider.code,
      net_payment_term: 2
    )
  end

  let(:stripe_customer) { create(:stripe_customer, customer:, payment_provider: stripe_provider, provider_customer_id: stripe_cus_id) }

  let(:external_subscription_id) { "sub_overdue-dunning-campaign-v1" }
  let(:plan) { create(:plan, organization:, pay_in_advance: true, amount_cents: 149_00) }

  let(:webhooks_sent) { [] }

  include_context "with webhook tracking"

  before do
    stub_pdf_generation
    stripe_customer
    create(:payment_method, payment_provider_customer: stripe_customer, provider_method_id: stripe_pm_id, is_default: true)
    dunning_campaign_threshold

    stub_request(:get, "https://api.stripe.com/v1/customers/#{stripe_customer.provider_customer_id}")
      .and_return(status: 200, body: get_stripe_fixtures("customer_retrieve_response.json") do |h|
        h[:invoice_settings][:default_payment_method] = stripe_pm_id
      end)
    stub_request(:get, "https://api.stripe.com/v1/customers/#{stripe_customer.provider_customer_id}/payment_methods/pm_123456")
      .and_return(status: 200, body: get_stripe_fixtures("retrieve_payment_method_response.json") do |h|
        h[:id] = stripe_pm_id
        h[:customer] = stripe_cus_id
      end)
    stub_request(:post, "https://api.stripe.com/v1/payment_intents")
      .and_return(
        status: 402,
        body: lambda { |_req|
          get_stripe_fixtures("payment_intent_card_declined_response.json") do |h|
            h[:error][:payment_intent][:id] = "pi_#{SecureRandom.hex}"
          end
        }
      )
    stub_request(:post, "https://api.stripe.com/v1/checkout/sessions")
      .and_return(status: 200, body: {url: "https://stripe.com/checkout/session/cs_test_123"}.to_json)

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

  it "handles multi-currency dunning with per-currency attempt tracking" do
    # Campaign: max_attempts=2, days_between_attempts=2
    # EUR threshold: 150 EUR (from let)
    # USD threshold: 100 USD
    create(:dunning_campaign_threshold, dunning_campaign:, amount_cents: 100_00, currency: "USD")

    # Create overdue invoices directly — multi-currency subscription API not yet shipped
    travel_to(DateTime.new(2025, 1, 1, 10)) do
      create(:invoice, organization:, customer:, currency: "EUR",
        payment_overdue: true, total_amount_cents: 149_00, ready_for_payment_processing: true)
      create(:invoice, organization:, customer:, currency: "USD",
        payment_overdue: true, total_amount_cents: 120_00, ready_for_payment_processing: true)
    end

    # Day 3: EUR below threshold (149 < 150), only USD dunned (120 >= 100)
    travel_to(DateTime.new(2025, 1, 3, 10)) do
      perform_dunning

      customer.reload
      expect(customer.dunning_currency_attempts).to eq("USD" => 1)
      expect(customer.payment_requests.count).to eq(1)
      expect(customer.payment_requests.last.amount_currency).to eq("USD")
    end

    # Day 4-5: within days_between_attempts, nothing happens
    travel_to(DateTime.new(2025, 1, 5, 10)) do
      perform_dunning

      customer.reload
      expect(customer.dunning_currency_attempts).to eq("USD" => 1)
      expect(customer.payment_requests.count).to eq(1)
    end

    # Push EUR over threshold with another overdue invoice
    travel_to(DateTime.new(2025, 1, 5, 18)) do
      create(:invoice, organization:, customer:, currency: "EUR",
        payment_overdue: true, total_amount_cents: 10_00, ready_for_payment_processing: true)
    end

    # Day 6: > 2 days since day 3. Both currencies now exceed thresholds.
    travel_to(DateTime.new(2025, 1, 6, 10)) do
      perform_dunning

      customer.reload
      expect(customer.dunning_currency_attempts).to eq("USD" => 2, "EUR" => 1)
      expect(customer.payment_requests.count).to eq(3) # 1 prev USD + 1 USD + 1 EUR
      expect(customer.payment_requests.where(amount_currency: "USD").count).to eq(2)
      expect(customer.payment_requests.where(amount_currency: "EUR").count).to eq(1)
    end

    # Day 9: USD already at max (2). Only EUR dunned, reaching max too.
    # Campaign finished webhook fires because all thresholds are now exhausted.
    travel_to(DateTime.new(2025, 1, 9, 10)) do
      perform_dunning

      customer.reload
      expect(customer.dunning_currency_attempts).to eq("USD" => 2, "EUR" => 2)
      expect(customer.payment_requests.where(amount_currency: "USD").count).to eq(2)
      expect(customer.payment_requests.where(amount_currency: "EUR").count).to eq(2)

      finished_webhooks = webhooks_sent.select { |w| w["webhook_type"] == "dunning_campaign.finished" }
      expect(finished_webhooks.count).to eq(1)
    end

    # Day 12: Both currencies at max. No more attempts, no additional webhooks.
    travel_to(DateTime.new(2025, 1, 12, 10)) do
      perform_dunning

      customer.reload
      expect(customer.payment_requests.count).to eq(4) # unchanged

      finished_webhooks = webhooks_sent.select { |w| w["webhook_type"] == "dunning_campaign.finished" }
      expect(finished_webhooks.count).to eq(1) # still just the one from day 9
    end
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

      expect(webhooks_sent.map { it["webhook_type"] }).to eq(%w[
        subscription.started
        invoice.created
        invoice.generated
        invoice.payment_failure
      ])
      invoice = customer.invoices.sole
      expect(invoice.payment_status).to eq("failed")
      expect(invoice.payment_due_date).to eq(Date.new(2025, 1, 3))
    end

    # The day after payment_due_date, the invoice should be marked as overdue
    travel_to(DateTime.new(2025, 1, 4, 13)) do
      perform_overdue_balance_update

      invoice = customer.invoices.sole
      expect(invoice).to be_payment_overdue
      expect(customer.overdue_balance_cents).to eq(149_00)

      # Performing dunning has no effect because the threshold is 150 and we have only 149 overdue
      perform_dunning
      expect(customer.payment_requests.count).to eq(0)
    end

    # Create a one-off invoice to reach the threshold
    travel_to(DateTime.new(2025, 1, 4, 18)) do
      addon = create(:add_on, organization:)
      create_one_off_invoice(customer, [addon], units: 3)
      perform_all_enqueued_jobs

      oneoff = customer.invoices.one_off.sole
      expect(oneoff.payment_status).to eq("failed")
      expect(oneoff.payment_due_date).to eq(Date.new(2025, 1, 6))
    end

    travel_to(DateTime.new(2025, 1, 7, 10)) do
      perform_overdue_balance_update
      expect(customer.invoices.one_off.sole).to be_payment_overdue

      expect(ActionMailer::Base.deliveries.count).to eq(0)
      perform_dunning
      # NOTE: Email is sent twice: first synchronously after Stripe response, and then when the webhook is received
      expect(ActionMailer::Base.deliveries.count).to eq(2)
      expect(ActionMailer::Base.deliveries.map(&:subject)).to all eq "Your overdue balance from ACME Corp"

      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to eq "Your overdue balance from ACME Corp"

      pr = customer.payment_requests.sole
      expect(pr.amount_cents).to eq(155_00)
    end

    # The next 2 days nothing happens
    [DateTime.new(2025, 1, 8, 10), DateTime.new(2025, 1, 9, 10)].each do |date|
      travel_to(date) do
        perform_overdue_balance_update
        perform_dunning
        expect(ActionMailer::Base.deliveries.count).to eq(2) # nothing new
      end
    end

    # The day after, we make another attempt
    travel_to(DateTime.new(2025, 1, 10, 10)) do
      perform_overdue_balance_update
      perform_dunning
      expect(ActionMailer::Base.deliveries.count).to eq(4)

      expect(customer.payment_requests.reload.map(&:amount_cents)).to all eq 155_00
    end

    # After the last attempt the invoice are still overdue but we don't try anymore
    travel_to(DateTime.new(2025, 1, 13, 13)) do
      perform_overdue_balance_update
      perform_dunning
      expect(ActionMailer::Base.deliveries.count).to eq(4) # Nothing new
    end
  end
end
