# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentRequests::Payments::CreateService do
  subject(:create_service) { described_class.new(payable: payment_request, payment_provider: provider, payment_method_params:) }

  let(:organization) { create(:organization) }
  let(:billing_entity) { organization.default_billing_entity }
  let(:customer) { create(:customer, organization:, payment_provider: provider, payment_provider_code:) }
  let(:provider) { "stripe" }
  let(:payment_provider_code) { "stripe_1" }
  let(:payment_method_params) { {} }
  let(:default_payment_method) { create(:payment_method, customer:, is_default: true) }

  let(:payment_request) do
    create(
      :payment_request,
      organization:,
      customer:,
      amount_cents: 799,
      amount_currency: "USD",
      invoices: [invoice_1, invoice_2]
    )
  end

  let(:invoice_1) do
    create(
      :invoice,
      organization:,
      customer:,
      total_amount_cents: 200,
      currency: "USD",
      ready_for_payment_processing: true
    )
  end

  let(:invoice_2) do
    create(
      :invoice,
      organization:,
      customer:,
      total_amount_cents: 599,
      currency: "USD",
      ready_for_payment_processing: true
    )
  end

  describe "#call" do
    let(:payment_provider) { create(:stripe_provider, code: payment_provider_code, organization:) }
    let(:provider_customer) { create(:stripe_customer, payment_provider:, customer:) }
    let(:provider_class) { PaymentProviders::Stripe::Payments::CreateService }
    let(:provider_service) { instance_double(provider_class) }

    let(:service_result) do
      BaseService::Result.new.tap do |r|
        r.payment = instance_double(Payment, payable_payment_status: "succeeded")
      end
    end

    before do
      provider_customer
      default_payment_method

      allow(provider_class)
        .to receive(:new)
        .with(
          payment: an_instance_of(Payment),
          reference: "#{billing_entity.name} - Overdue invoices",
          metadata: {
            lago_customer_id: customer.id,
            lago_payable_id: payment_request.id,
            lago_payable_type: "PaymentRequest"
          }
        ).and_return(provider_service)
      allow(provider_service).to receive(:call!)
        .and_return(service_result)
    end

    context "with adyen payment provider" do
      let(:provider) { "adyen" }
      let(:payment_provider) { create(:adyen_provider, code: payment_provider_code, organization:) }
      let(:provider_customer) { create(:adyen_customer, payment_provider:, customer:) }

      let(:provider_class) { PaymentProviders::Adyen::Payments::CreateService }
      let(:provider_service) { instance_double(provider_class) }

      let(:service_result) do
        BaseService::Result.new.tap do |r|
          r.payment = instance_double(Payment, payable_payment_status: "succeeded")
        end
      end

      it "creates a payment and calls the adyen service" do
        result = create_service.call

        expect(result).to be_success
        expect(result.payable).to eq(payment_request)
        expect(result.payment).to be_present

        expect(result.payable).to be_payment_succeeded
        expect(result.payable.payment_attempts).to eq(1)
        expect(result.payable.ready_for_payment_processing).to eq(false)

        payment = result.payment
        expect(payment.payment_provider).to eq(payment_provider)
        expect(payment.payment_provider_customer).to eq(provider_customer)
        expect(payment.amount_cents).to eq(payment_request.total_amount_cents)
        expect(payment.amount_currency).to eq(payment_request.currency)
        expect(payment.payable).to eq(payment_request)

        expect(provider_class).to have_received(:new)
        expect(provider_service).to have_received(:call!)
      end

      it "updates invoice payment status to succeeded" do
        create_service.call

        expect(invoice_1.reload).to be_payment_succeeded
        expect(invoice_2.reload).to be_payment_succeeded
      end

      it "does not send a payment requested email" do
        expect { create_service.call }
          .not_to have_enqueued_mail(PaymentRequestMailer, :requested)
      end

      context "when issue_receipts_enabled is true", :premium do
        before { organization.update!(premium_integrations: %w[issue_receipts]) }

        it "enqueues a payment receipt job" do
          expect { create_service.call }.to have_enqueued_job(PaymentReceipts::CreateJob)
        end
      end

      context "when the payment fails" do
        let(:service_result) do
          BaseService::Result.new.tap do |r|
            r.payment = instance_double(Payment, payable_payment_status: "failed")
          end
        end

        it "sends a payment requested email" do
          expect { create_service.call }
            .to have_enqueued_mail(PaymentRequestMailer, :requested)
            .with(params: {payment_request:}, args: [])
        end
      end
    end

    context "with gocardless payment provider" do
      let(:provider) { "gocardless" }
      let(:payment_provider) { create(:gocardless_provider, code: payment_provider_code, organization:) }
      let(:provider_customer) { create(:gocardless_customer, payment_provider:, customer:) }

      let(:provider_class) { PaymentProviders::Gocardless::Payments::CreateService }
      let(:provider_service) { instance_double(provider_class) }

      it "creates a payment and calls the gocardless service" do
        result = create_service.call

        expect(result).to be_success
        expect(result.payable).to eq(payment_request)
        expect(result.payment).to be_present

        expect(result.payable).to be_payment_succeeded
        expect(result.payable.payment_attempts).to eq(1)
        expect(result.payable.ready_for_payment_processing).to eq(false)

        payment = result.payment
        expect(payment.payment_provider).to eq(payment_provider)
        expect(payment.payment_provider_customer).to eq(provider_customer)
        expect(payment.amount_cents).to eq(payment_request.total_amount_cents)
        expect(payment.amount_currency).to eq(payment_request.currency)
        expect(payment.payable).to eq(payment_request)

        expect(provider_class).to have_received(:new)
        expect(provider_service).to have_received(:call!)
      end

      it "updates invoice payment status to succeeded" do
        create_service.call

        expect(invoice_1.reload).to be_payment_succeeded
        expect(invoice_2.reload).to be_payment_succeeded
      end

      it "does not send a payment requested email" do
        expect { create_service.call }
          .not_to have_enqueued_mail(PaymentRequestMailer, :requested)
      end

      context "when the payment fails" do
        let(:service_result) do
          BaseService::Result.new.tap do |r|
            r.payment = instance_double(Payment, payable_payment_status: "failed")
          end
        end

        it "sends a payment requested email" do
          expect { create_service.call }
            .to have_enqueued_mail(PaymentRequestMailer, :requested)
            .with(params: {payment_request:}, args: [])
        end
      end
    end

    context "with stripe payment provider" do
      it "creates a payment and calls the stripe service" do
        result = create_service.call

        expect(result).to be_success
        expect(result.payable).to eq(payment_request)
        expect(result.payment).to be_present

        expect(result.payable).to be_payment_succeeded
        expect(result.payable.payment_attempts).to eq(1)
        expect(result.payable.ready_for_payment_processing).to eq(false)

        payment = result.payment
        expect(payment.payment_provider).to eq(payment_provider)
        expect(payment.payment_provider_customer).to eq(provider_customer)
        expect(payment.amount_cents).to eq(payment_request.total_amount_cents)
        expect(payment.amount_currency).to eq(payment_request.currency)
        expect(payment.payable).to eq(payment_request)

        expect(provider_class).to have_received(:new)
        expect(provider_service).to have_received(:call!)
      end

      it "updates invoice payment status to succeeded" do
        create_service.call

        expect(invoice_1.reload).to be_payment_succeeded
        expect(invoice_2.reload).to be_payment_succeeded
      end

      it "updates invoice paid amount" do
        create_service.call

        expect(invoice_1.reload.total_paid_amount_cents).to eq(invoice_1.total_amount_cents)
        expect(invoice_2.reload.total_paid_amount_cents).to eq(invoice_2.total_amount_cents)
      end

      it "does not send a payment requested email" do
        expect { create_service.call }
          .not_to have_enqueued_mail(PaymentRequestMailer, :requested)
      end

      context "when the payment fails" do
        let(:service_result) do
          BaseService::Result.new.tap do |r|
            r.payment = instance_double(Payment, payable_payment_status: "failed")
          end
        end

        it "sends a payment requested email" do
          expect { create_service.call }
            .to have_enqueued_mail(PaymentRequestMailer, :requested)
            .with(params: {payment_request:}, args: [])
        end

        context "when invoices were already paid through another path" do
          before do
            invoice_1.payment_succeeded!
            invoice_2.payment_succeeded!
          end

          it "leaves already-succeeded invoices untouched" do
            expect { create_service.call }
              .to not_change { invoice_1.reload.payment_status }
              .and not_change { invoice_2.reload.payment_status }

            expect(invoice_1.reload).to be_payment_succeeded
            expect(invoice_2.reload).to be_payment_succeeded
          end
        end
      end

      context "when manual payment method is passed in params" do
        let(:payment_method_params) { {payment_method_type: "manual"} }

        it "does not attach payment method to payment" do
          result = create_service.call

          expect(result).to be_success
          expect(result.payment.payment_method_id).to be_nil
        end
      end

      context "when valid payment method is passed in params" do
        let(:payment_method) { create(:payment_method, customer:, is_default: false) }
        let(:payment_method_params) { {payment_method_id: payment_method.id} }

        it "attaches correct payment method" do
          result = create_service.call

          expect(result).to be_success
          expect(result.payment.payment_method_id).to eq(payment_method.id)
        end
      end

      context "when payment method is NOT passed in params" do
        it "creates payment with customer default payment method" do
          result = create_service.call

          expect(result).to be_success
          expect(result.payment.payment_method_id).to eq(default_payment_method.id)
        end
      end
    end

    context "when payment request payment status is succeeded" do
      let(:payment_request) do
        create(
          :payment_request,
          organization:,
          customer:,
          payment_status: "succeeded",
          amount_cents: 799,
          amount_currency: "EUR",
          invoices: [invoice_1, invoice_2]
        )
      end

      it "does not creates a payment" do
        result = create_service.call

        expect(result).to be_success

        expect(result.payable).to be_payment_succeeded
        expect(result.payable.payment_attempts).to eq(0)
        expect(result.payment).to be_nil

        expect(provider_class).not_to have_received(:new)
      end
    end

    context "with no payment provider" do
      let(:payment_provider) { nil }

      it "does not creates a stripe payment" do
        result = create_service.call

        expect(result).to be_success

        expect(result.payable).to eq(payment_request)
        expect(result.payment).to be_nil

        expect(provider_class).not_to have_received(:new)
      end
    end

    context "with 0 amount" do
      let(:payment_request) do
        create(
          :payment_request,
          organization:,
          customer:,
          amount_cents: 0,
          amount_currency: "EUR",
          invoices: [invoice]
        )
      end

      let(:invoice) do
        create(
          :invoice,
          organization:,
          customer:,
          total_amount_cents: 0,
          currency: "EUR"
        )
      end

      it "does not creates a stripe payment" do
        result = create_service.call

        expect(result).to be_success
        expect(result.payable).to eq(payment_request)
        expect(result.payment).to be_nil
        expect(result.payable).to be_payment_succeeded
        expect(provider_class).not_to have_received(:new)
      end
    end

    context "when customer does not have a provider customer id" do
      before { provider_customer.update!(provider_customer_id: nil) }

      it "does not creates a stripe payment" do
        result = create_service.call

        expect(result).to be_success

        expect(result.payable).to eq(payment_request)
        expect(result.payment).to be_nil
        expect(provider_class).not_to have_received(:new)
      end
    end

    context "when some invoices are already paid" do
      let(:invoice_1) do
        create(
          :invoice,
          organization:,
          customer:,
          total_amount_cents: 200,
          currency: "USD",
          ready_for_payment_processing: false
        )
      end

      it "does not create a stripe payment" do
        result = create_service.call

        expect(result).to be_success

        expect(result.payable).to eq(payment_request)
        expect(result.payment).to be_nil
        expect(provider_class).not_to have_received(:new)
      end
    end

    context "when the provider raises AlreadyPaidError" do
      before do
        allow(provider_service).to receive(:call!).and_raise(Invoices::Payments::AlreadyPaidError)
      end

      it "skips silently and drops the unused pending payment" do
        result = create_service.call

        expect(result).to be_success
        expect(result.payment).to be_nil
        expect(payment_request.reload.payments).to be_empty
      end

      it "does not send the payment request email" do
        expect { create_service.call }.not_to have_enqueued_mail(PaymentRequestMailer, :requested)
      end
    end

    context "when provider service raises a service failure" do
      let(:service_result) do
        BaseService::Result.new.tap do |r|
          r.payment = instance_double(Payment, status: "pending", payable_payment_status: "pending")
          r.error_message = "error"
          r.error_code = "code"
          r.reraise = true
        end
      end

      before do
        allow(provider_service).to receive(:call!)
          .and_raise(BaseService::ServiceFailure.new(service_result, code: "code", error_message: "error"))
      end

      it "re-reaise the error and delivers an error webhook" do
        expect { create_service.call }
          .to raise_error(BaseService::ServiceFailure)
          .and enqueue_job(SendWebhookJob)
          .with(
            "payment_request.payment_failure",
            payment_request,
            provider_customer_id: provider_customer.provider_customer_id,
            provider_error: {
              message: "error",
              error_code: "code"
            }
          ).on_queue(webhook_queue)
          .and have_enqueued_mail(PaymentRequestMailer, :requested)
          .with(params: {payment_request:}, args: [])
      end

      context "when payment has a payable_payment_status" do
        let(:service_result) do
          BaseService::Result.new.tap do |r|
            r.payment = instance_double(Payment, payable_payment_status: "failed")
            r.error_message = "error"
            r.error_code = "code"
            r.reraise = true
          end
        end

        it "updates the payment request payment status" do
          expect { create_service.call }
            .to raise_error(BaseService::ServiceFailure)

          expect(payment_request.reload).to be_payment_failed
        end
      end

      context "when payable_payment_status is pending" do
        let(:service_result) do
          BaseService::Result.new.tap do |r|
            r.payment = instance_double(Payment, status: "failed", payable_payment_status: "pending")
            r.error_message = "stripe_error"
            r.error_code = "amount_too_small"
          end
        end

        it "re-reaise the error and delivers an error webhook" do
          result = create_service.call

          expect(result).to be_success
          expect(result.payable).to eq(payment_request)
          expect(result.payment).to be_present

          expect(result.payment.status).to eq("failed")
          expect(result.payment.payable_payment_status).to eq("pending")

          expect(provider_class).to have_received(:new)
          expect(provider_service).to have_received(:call!)
        end
      end
    end

    context "when payment status is processing" do
      let(:service_result) do
        BaseService::Result.new.tap do |r|
          r.payment = instance_double(Payment, payable_payment_status: "pending", status: "processing")
        end
      end

      it "creates a payment" do
        result = create_service.call

        expect(result).to be_success
        expect(result.payable).to eq(payment_request)
        expect(result.payment).to be_present

        expect(result.payable).to be_payment_pending
        expect(result.payable.payment_attempts).to eq(1)
        expect(result.payable.ready_for_payment_processing).to eq(false)

        payment = result.payment
        expect(payment.payment_provider).to eq(payment_provider)
        expect(payment.payment_provider_customer).to eq(provider_customer)
        expect(payment.amount_cents).to eq(payment_request.total_amount_cents)
        expect(payment.amount_currency).to eq(payment_request.currency)
        expect(payment.payable_payment_status).to eq("pending")
        expect(payment.payable).to eq(payment_request)

        expect(provider_class).to have_received(:new)
        expect(provider_service).to have_received(:call!)
      end
    end

    context "when a payment exits" do
      let(:payment) do
        create(
          :payment,
          payable: payment_request,
          payment_provider:,
          payment_provider_customer: provider_customer,
          amount_cents: payment_request.total_amount_cents,
          amount_currency: payment_request.currency,
          status: "pending",
          payable_payment_status: payment_status
        )
      end

      let(:payment_status) { "pending" }

      before { payment }

      it "retrieves the payment for processing" do
        result = create_service.call

        expect(result).to be_success
        expect(result.payable).to eq(payment_request)
        expect(result.payment).to eq(payment)

        expect(payment.payment_provider).to eq(payment_provider)
        expect(payment.payment_provider_customer).to eq(provider_customer)
        expect(payment.amount_cents).to eq(payment_request.total_amount_cents)
        expect(payment.amount_currency).to eq(payment_request.currency)

        expect(provider_class).to have_received(:new)
        expect(provider_service).to have_received(:call!)
      end

      context "when payment is already processing" do
        let(:payment_status) { "processing" }

        it "does not creates a payment" do
          result = create_service.call

          expect(result).to be_success
          expect(result.payable).to eq(payment_request)
          expect(result.payment).to eq(payment)

          expect(provider_class).not_to have_received(:new)
          expect(provider_service).not_to have_received(:call!)
        end
      end
    end
  end

  describe "#call_async" do
    context "with adyen payment provider" do
      let(:payment_provider) { "adyen" }

      it "enqueues a job to create a adyen payment" do
        expect do
          create_service.call_async
        end.to have_enqueued_job(PaymentRequests::Payments::CreateJob)
      end
    end

    context "with gocardless payment provider" do
      let(:payment_provider) { "gocardless" }

      it "enqueues a job to create a gocardless payment" do
        expect do
          create_service.call_async
        end.to have_enqueued_job(PaymentRequests::Payments::CreateJob)
      end
    end

    context "with strip payment provider" do
      let(:payment_provider) { "stripe" }

      it "enqueues a job to create a stripe payment" do
        expect do
          create_service.call_async
        end.to have_enqueued_job(PaymentRequests::Payments::CreateJob)
      end
    end
  end
end
