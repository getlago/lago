# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::StripeService do
  subject(:stripe_service) { described_class.new(stripe_customer) }

  let(:customer) { create(:customer, name: customer_name, organization:) }
  let(:stripe_provider) { create(:stripe_provider) }
  let(:organization) { stripe_provider.organization }
  let(:customer_name) { nil }

  let(:stripe_customer) do
    create(:stripe_customer, customer:, provider_customer_id: nil)
  end

  describe "#create" do
    context "when customer is deleted" do
      before do
        customer.discard!
        stripe_customer.reload
      end

      it "returns a deleted_customer failure" do
        result = stripe_service.create

        expect(result).to be_success
        expect(result.stripe_customer).to be_nil
      end
    end

    context "when customer name is present" do
      let(:customer_name) { "Big inc" }

      it "creates a stripe customer with the customer name" do
        allow(Stripe::Customer).to receive(:create)
          .and_return(Stripe::Customer.new(id: "cus_123456"))

        expect do
          stripe_service.create
        end.to have_enqueued_job_after_commit(PaymentProviderCustomers::StripeCheckoutUrlJob).with(stripe_customer)

        expect(Stripe::Customer).to have_received(:create).with(hash_including(name: customer_name), anything)
      end
    end

    context "when stripe customer is created and has customer_balance payment method" do
      before do
        allow(Stripe::Customer).to receive(:create)
          .and_return(Stripe::Customer.new(id: "cus_123456"))

        stripe_customer.update(provider_payment_methods: ["customer_balance"])
      end

      it "enqueues StripeSyncFundingInstructionsJob" do
        stripe_service.create

        expect(PaymentProviderCustomers::StripeSyncFundingInstructionsJob)
          .to have_been_enqueued.with(stripe_customer)
        expect(PaymentProviderCustomers::StripeCheckoutUrlJob).not_to have_been_enqueued
      end
    end

    context "when customer name is not present" do
      it "creates a stripe customer with the customer firstname and lastname" do
        allow(Stripe::Customer).to receive(:create)
          .and_return(Stripe::Customer.new(id: "cus_123456"))
        stripe_service.create

        expected_name = "#{customer.firstname} #{customer.lastname}"
        expect(Stripe::Customer).to have_received(:create).with(hash_including(name: expected_name), anything)
      end
    end

    it "creates the stripe customer" do
      allow(Stripe::Customer).to receive(:create)
        .and_return(Stripe::Customer.new(id: "cus_123456"))

      result = stripe_service.create

      expect(Stripe::Customer).to have_received(:create)

      expect(result.stripe_customer.provider_customer_id).to eq("cus_123456")
    end

    it "delivers a success webhook" do
      allow(Stripe::Customer).to receive(:create)
        .and_return(Stripe::Customer.new(id: "cus_123456"))

      stripe_service.create

      expect(Stripe::Customer).to have_received(:create)

      expect(SendWebhookJob).to have_been_enqueued
        .with("customer.payment_provider_created", customer)
    end

    context "when customer already have a stripe customer id" do
      let(:stripe_customer) do
        create(:stripe_customer, customer:, provider_customer_id: "cus_123456")
      end

      it "does not call stripe API" do
        allow(Stripe::Customer).to receive(:create)

        stripe_service.create

        expect(Stripe::Customer).not_to have_received(:create)
      end
    end

    context "when no payment provider is connected" do
      let(:stripe_customer) do
        create(:stripe_customer, customer:, provider_customer_id: nil)
      end

      before { stripe_provider.destroy! }

      it "does not call stripe API" do
        allow(Stripe::Customer).to receive(:create)

        stripe_service.create

        expect(Stripe::Customer).not_to have_received(:create)
      end

      it "returns success" do
        allow(Stripe::Customer).to receive(:create)

        result = stripe_service.create

        expect(result).to be_success
      end
    end

    context "when payment provider has incorrect API key" do
      before do
        allow(Stripe::Customer).to receive(:create)
          .and_raise(::Stripe::AuthenticationError.new("API key invalid."))
      end

      it "returns an unauthorized error" do
        result = stripe_service.create

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::UnauthorizedFailure)
        expect(result.error.message).to eq("Stripe authentication failed. API key invalid.")
      end

      it "delivers an error webhook" do
        expect { stripe_service.create }.to enqueue_job(SendWebhookJob)
          .with(
            "customer.payment_provider_error",
            customer,
            provider_error: {
              message: "API key invalid.",
              error_code: nil
            }
          ).on_queue(webhook_queue)
      end
    end

    context "when failing to create the customer" do
      it "delivers an error webhook" do
        allow(Stripe::Customer).to receive(:create)
          .and_raise(::Stripe::InvalidRequestError.new("error", {}))

        stripe_service.create

        expect(Stripe::Customer).to have_received(:create)

        expect(SendWebhookJob).to have_been_enqueued
          .with(
            "customer.payment_provider_error",
            customer,
            provider_error: {
              message: "error",
              error_code: nil
            }
          )
      end
    end

    context "with idempotency issue" do
      before do
        allow(Stripe::Customer).to receive(:create)
          .and_raise(Stripe::IdempotencyError.new("idempotency"))

        allow(Stripe::Customer).to receive(:list)
          .and_return([Stripe::Customer.new(id: "cus_123456")])
      end

      it "fetches the stripe customer from the API" do
        result = stripe_service.create

        expect(result.stripe_customer.provider_customer_id).to eq("cus_123456")
      end
    end
  end

  describe "#update" do
    let(:stripe_customer) do
      create(:stripe_customer, customer:, provider_customer_id:)
    end

    before { stripe_customer }

    context "when stripe customer provider_customer_id is present" do
      let(:provider_customer_id) { "cus_123456" }

      context "when stripe raises an error" do
        before do
          allow(Stripe::Customer).to receive(:update).and_raise(stripe_error)
        end

        context "when stripe raises an invalid request error" do
          let(:stripe_error) { ::Stripe::InvalidRequestError.new("Invalid request", nil) }

          it "returns an error result" do
            result = stripe_service.update

            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::ThirdPartyFailure)
            expect(result.error.third_party).to eq("Stripe")
            expect(result.error.error_code).to be_nil
            expect(result.error.error_message).to eq("Invalid request")
          end

          it "delivers an error webhook" do
            expect { stripe_service.update }.to enqueue_job(SendWebhookJob)
              .with(
                "customer.payment_provider_error",
                customer,
                provider_error: {
                  message: "Invalid request",
                  error_code: nil
                }
              ).on_queue(webhook_queue)
          end
        end

        context "when stripe raises a permission error" do
          let(:stripe_error) { Stripe::PermissionError.new("Permission error") }

          it "returns an error result" do
            result = stripe_service.update

            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::ThirdPartyFailure)
            expect(result.error.third_party).to eq("Stripe")
            expect(result.error.error_code).to be_nil
            expect(result.error.error_message).to eq("Permission error")
          end

          it "delivers an error webhook" do
            expect { stripe_service.update }.to enqueue_job(SendWebhookJob)
              .with(
                "customer.payment_provider_error",
                customer,
                provider_error: {
                  message: "Permission error",
                  error_code: nil
                }
              ).on_queue(webhook_queue)
          end
        end

        context "when stripe raises an authentication error" do
          let(:stripe_error) { ::Stripe::AuthenticationError.new("Invalid username.") }

          it "returns an error result" do
            result = stripe_service.update

            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::UnauthorizedFailure)
            expect(result.error.message).to eq("Stripe authentication failed. Invalid username.")
          end

          it "delivers an error webhook" do
            expect { stripe_service.update }.to enqueue_job(SendWebhookJob)
              .with(
                "customer.payment_provider_error",
                customer,
                provider_error: {
                  message: "Invalid username.",
                  error_code: nil
                }
              ).on_queue(webhook_queue)
          end
        end
      end

      context "when no stripe error is raised" do
        before do
          allow(Stripe::Customer).to receive(:update).and_return(true)
        end

        context "when stripe payment provider is present" do
          it "calls stripe API" do
            stripe_service.update

            expect(Stripe::Customer).to have_received(:update)
          end

          it "returns a successful result" do
            result = stripe_service.update

            expect(result).to be_success
          end

          it "does not deliver an error webhook" do
            expect { stripe_service.update }.not_to enqueue_job(SendWebhookJob)
          end
        end

        context "when stripe payment provider is not present" do
          before { stripe_provider.destroy! }

          it "does not call stripe API" do
            stripe_service.update

            expect(Stripe::Customer).not_to have_received(:update)
          end

          it "returns a successful result" do
            result = stripe_service.update

            expect(result).to be_success
          end

          it "does not deliver an error webhook" do
            expect { stripe_service.update }.not_to enqueue_job(SendWebhookJob)
          end
        end
      end
    end

    context "when updating a stripe customer with customer_balance method" do
      let(:provider_customer_id) { "cus_123456" }

      before do
        stripe_customer.update(provider_payment_methods: ["customer_balance"])
        allow(Stripe::Customer).to receive(:update).and_return(true)
      end

      it "enqueues StripeSyncFundingInstructionsJob" do
        stripe_service.update

        expect(PaymentProviderCustomers::StripeSyncFundingInstructionsJob)
          .to have_been_enqueued.with(stripe_customer)
      end
    end

    context "when stripe customer provider_customer_id is not present" do
      let(:provider_customer_id) { nil }

      before do
        allow(Stripe::Customer).to receive(:update).and_return(true)
      end

      context "when stripe payment provider is present" do
        it "does not call stripe API" do
          stripe_service.update

          expect(Stripe::Customer).not_to have_received(:update)
        end

        it "returns a successful result" do
          result = stripe_service.update

          expect(result).to be_success
        end

        it "does not deliver an error webhook" do
          expect { stripe_service.update }.not_to enqueue_job(SendWebhookJob)
        end
      end

      context "when stripe payment provider is not present" do
        before { stripe_provider.destroy! }

        it "does not call stripe API" do
          stripe_service.update

          expect(Stripe::Customer).not_to have_received(:update)
        end

        it "returns a successful result" do
          result = stripe_service.update

          expect(result).to be_success
        end

        it "does not deliver an error webhook" do
          expect { stripe_service.update }.not_to enqueue_job(SendWebhookJob)
        end
      end
    end
  end

  describe "#delete_payment_method" do
    subject(:stripe_service) { described_class.new }

    let(:payment_method_id) { "card_12345" }

    let(:stripe_customer) do
      create(
        :stripe_customer,
        customer:,
        provider_customer_id: "cus_123456",
        payment_method_id:
      )
    end

    it "removes the customer payment method" do
      result = stripe_service.delete_payment_method(
        organization_id: organization.id,
        stripe_customer_id: stripe_customer.provider_customer_id,
        payment_method_id:
      )

      expect(result).to be_success
      expect(result.stripe_customer.payment_method_id).to be_nil
    end

    context "when customer payment method is not the deleted one" do
      it "does not remove the customer payment method" do
        result = stripe_service.delete_payment_method(
          organization_id: organization.id,
          stripe_customer_id: stripe_customer.provider_customer_id,
          payment_method_id: "other_payment_method_id"
        )

        expect(result).to be_success
        expect(result.stripe_customer.payment_method_id).to eq(payment_method_id)
      end
    end

    context "when the customer has a payment method" do
      let(:payment_method) do
        create(:payment_method, customer:, provider_method_id: payment_method_id)
      end

      before { payment_method }

      it "discards the payment method" do
        result = stripe_service.delete_payment_method(
          organization_id: organization.id,
          stripe_customer_id: stripe_customer.provider_customer_id,
          payment_method_id:
        )

        expect(result).to be_success
        expect(result.stripe_customer.payment_method_id).to be_nil
        expect(result.payment_method).to eq(payment_method)
        expect(payment_method.reload.discarded?).to be true
      end

      context "when payment method does not exist" do
        it "does not raise an error" do
          result = stripe_service.delete_payment_method(
            organization_id: organization.id,
            stripe_customer_id: stripe_customer.provider_customer_id,
            payment_method_id: "non_existent_pm"
          )

          expect(result).to be_success
          expect(result.payment_method).to be_nil
        end
      end
    end

    context "when customer is not found" do
      it "returns an empty result" do
        result = stripe_service.delete_payment_method(
          organization_id: organization.id,
          stripe_customer_id: "cus_InvaLid",
          payment_method_id: "pm_123456"
        )

        expect(result).to be_success
        expect(result.stripe_customer).to be_nil
      end

      context "when customer in metadata is not found" do
        it "returns an empty response" do
          result = stripe_service.delete_payment_method(
            organization_id: organization.id,
            stripe_customer_id: "cus_InvaLid",
            payment_method_id: "pm_123456",
            metadata: {
              lago_customer_id: SecureRandom.uuid
            }
          )

          expect(result).to be_success
          expect(result.stripe_customer).to be_nil
        end
      end

      context "when customer in metadata exists" do
        it "returns a not found error" do
          result = stripe_service.delete_payment_method(
            organization_id: organization.id,
            stripe_customer_id: "cus_InvaLid",
            payment_method_id: "pm_123456",
            metadata: {
              lago_customer_id: customer.id
            }
          )

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.message).to eq("stripe_customer_not_found")
        end
      end
    end
  end

  describe "#generate_checkout_url" do
    it "delivers a webhook with checkout url" do
      allow(::Stripe::Checkout::Session).to receive(:create)
        .and_return({"url" => "https://example.com"})

      stripe_service.generate_checkout_url

      expect(SendWebhookJob).to have_been_enqueued
        .with("customer.checkout_url_generated", customer, checkout_url: "https://example.com")
    end

    context "without any customer" do
      let(:customer) { create(:customer, :deleted, organization:) }

      it "does not deliver a webhook" do
        described_class.new(stripe_customer.reload).generate_checkout_url

        expect(SendWebhookJob).not_to have_been_enqueued
          .with("customer.checkout_url_generated", customer, checkout_url: "https://example.com")
      end
    end

    context "when customer has no payment method to be setup" do
      let(:stripe_customer) { create(:stripe_customer, customer:, provider_customer_id: nil, provider_payment_methods: %w[crypto]) }

      it "does not deliver a webhook" do
        described_class.new(stripe_customer.reload).generate_checkout_url

        expect(SendWebhookJob).not_to have_been_enqueued
          .with("customer.checkout_url_generated", customer, checkout_url: "https://example.com")
      end
    end

    context "when stripe raises an invalid request error" do
      let(:stripe_error) { ::Stripe::InvalidRequestError.new("wrong request!", {}) }

      before { allow(::Stripe::Checkout::Session).to receive(:create).and_raise(stripe_error) }

      it "returns an error result" do
        result = described_class.new(stripe_customer).generate_checkout_url

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ThirdPartyFailure)
        expect(result.error.message).to eq("Stripe:  - wrong request!")
      end
    end

    context "when stripe raises an authentication error" do
      let(:stripe_error) { ::Stripe::AuthenticationError.new("Expired API Key provided") }

      before { allow(::Stripe::Checkout::Session).to receive(:create).and_raise(stripe_error) }

      it "returns an error result" do
        result = described_class.new(stripe_customer).generate_checkout_url

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::UnauthorizedFailure)
        expect(result.error.message).to eq("Stripe authentication failed. Expired API Key provided")
      end

      it "delivers an error webhook" do
        expect { described_class.new(stripe_customer).generate_checkout_url }.to enqueue_job(SendWebhookJob)
          .with(
            "customer.payment_provider_error",
            customer,
            provider_error: {
              message: "Expired API Key provided",
              error_code: nil
            }
          ).on_queue(webhook_queue)
      end
    end

    context "when payment methods do not require setup" do
      let(:stripe_customer) { create(:stripe_customer, customer:, provider_customer_id: nil, provider_payment_methods: %w[crypto]) }

      it "returns an error result" do
        result = described_class.new(stripe_customer).generate_checkout_url

        expect(result).not_to be_success
        expect(result.error.messages).to eq(provider_payment_methods: ["no_payment_methods_to_setup_available"])
      end
    end
  end

  describe "#success_redirect_url" do
    subject(:success_redirect_url) { stripe_service.__send__(:success_redirect_url) }

    context "when payment provider has success redirect url" do
      it "returns payment provider's success redirect url" do
        expect(success_redirect_url).to eq(stripe_provider.success_redirect_url)
      end
    end

    context "when payment provider has no success redirect url" do
      let(:stripe_provider) { create(:stripe_provider, success_redirect_url: nil) }

      it "returns the default success redirect url" do
        expect(success_redirect_url).to eq(PaymentProviders::StripeProvider::SUCCESS_REDIRECT_URL)
      end
    end
  end
end
