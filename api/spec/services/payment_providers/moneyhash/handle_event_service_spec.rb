# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Moneyhash::HandleEventService do
  subject(:event_service) { described_class.new(organization:, event_json:) }

  let(:organization) { create(:organization) }
  let(:moneyhash_provider) { create(:moneyhash_provider, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:moneyhash_customer) { create(:moneyhash_customer, customer:) }

  # Intent
  # handle event - intent.processed <-
  # handle event - intent.time_expired <-
  describe "#handle_intent_event" do
    let(:event_json) { JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/intent.processed.json"))) }
    let(:invoice) { create(:invoice, organization:, customer:) }
    let(:payment) { create(:payment, payment_provider: moneyhash_provider, provider_payment_id: event_json.dig("data", "intent_id"), payable: invoice) }

    before do
      payment
      event_json["data"]["intent"]["custom_fields"]["lago_payable_type"] = "Invoice"
      event_json["data"]["intent"]["custom_fields"]["lago_payable_id"] = invoice.id
    end

    it "handles intent.processed event" do
      result = event_service.call

      payment.reload
      expect(result).to be_success
      expect(payment.status).to eq("succeeded")
      expect(payment.payable_payment_status).to eq("succeeded")
      expect(payment.payable.payment_status).to eq("succeeded")
    end

    context "when event is intent.time_expired" do
      let(:event_json) { JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/intent.time_expired.json"))) }

      it "handles the event" do
        result = event_service.call

        payment.reload
        expect(result).to be_success
        expect(payment.status).to eq("failed")
        expect(payment.payable_payment_status).to eq("failed")
        expect(payment.payable.payment_status).to eq("failed")
      end
    end
  end

  # Transaction
  # handle event - transaction.purchase.successful <-
  # handle event - transaction.purchase.pending_authentication <-
  # handle event - transaction.purchase.failed <-
  describe "#handle_transaction_event" do
    let(:payment) { create(:payment, payment_provider: moneyhash_provider, provider_payment_id: event_json.dig("intent", "id"), payable: invoice) }
    let(:invoice) { create(:invoice, organization:, customer:) }

    before do
      moneyhash_provider
      moneyhash_customer
      payment

      event_json["intent"]["custom_fields"]["lago_payable_type"] = "Invoice"
      event_json["intent"]["custom_fields"]["lago_payable_id"] = invoice.id
      event_json["intent"]["custom_fields"]["lago_customer_id"] = moneyhash_customer.customer_id
    end

    context "when event is transaction.purchase.successful" do
      let(:event_json) { JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/transaction.purchase.successful.json"))) }

      it "handles transaction.purchase.successful event" do
        result = event_service.call

        payment.reload
        expect(result).to be_success
        expect(payment.status).to eq("succeeded")
        expect(payment.payable_payment_status).to eq("succeeded")
        expect(payment.payable.payment_status).to eq("succeeded")
      end
    end

    context "when event is transaction.purchase.pending_authentication" do
      let(:event_json) { JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/transaction.purchase.pending_authentication.json"))) }

      it "handles the event" do
        result = event_service.call

        payment.reload
        expect(result).to be_success
        expect(payment.status).to eq("processing")
        expect(payment.payable_payment_status).to eq("pending")
        expect(payment.payable.payment_status).to eq("pending")
      end
    end

    context "when event is transaction.purchase.failed" do
      let(:event_json) { JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/transaction.purchase.failed.json"))) }

      it "handles the event" do
        result = event_service.call

        payment.reload
        expect(result).to be_success
        expect(payment.status).to eq("failed")
        expect(payment.payable_payment_status).to eq("failed")
        expect(payment.payable.payment_status).to eq("failed")
      end
    end
  end

  describe "amount_cents handling in metadata" do
    let(:payment_service) { instance_double(Invoices::Payments::MoneyhashService) }
    let(:service_result) { BaseService::Result.new }

    before do
      allow(Invoices::Payments::MoneyhashService).to receive(:new).and_return(payment_service)
      allow(payment_service).to receive(:update_payment_status).and_return(service_result)
    end

    context "when handling an intent event with a scalar amount in major units" do
      let(:event_json) { JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/intent.processed.json"))) }

      it "passes amount_cents converted to minor units as a dedicated kwarg" do
        event_service.call

        expect(payment_service).to have_received(:update_payment_status).with(
          hash_including(amount_cents: 500)
        )
      end
    end

    context "when handling a transaction event whose amount is a hash with major-unit value" do
      let(:event_json) { JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/transaction.purchase.successful.json"))) }

      it "extracts the value from the amount hash and converts to cents" do
        event_service.call

        expect(payment_service).to have_received(:update_payment_status).with(
          hash_including(amount_cents: 710)
        )
      end

      it "does not raise when amount is a hash rather than a scalar" do
        expect { event_service.call }.not_to raise_error
      end
    end
  end

  # Card Token
  # handle event - card_token.created <-
  # handle event - card_token.updated <-
  # handle event - card_token.deleted <-
  describe "#handle_card_event" do
    let(:event_json) { JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/card_token.created.json"))) }

    before do
      moneyhash_provider
      moneyhash_customer

      event_json["data"]["card_token"]["custom_fields"]["lago_customer_id"] = moneyhash_customer.customer_id
    end

    it "handles card_token.created event" do
      result = event_service.call

      expect(result).to be_success
      moneyhash_customer.reload
      expect(moneyhash_customer.payment_method_id).to eq(event_json.dig("data", "card_token", "id"))
    end

    it "extracts and stores card details in PaymentMethod.details" do
      result = event_service.call

      expect(result).to be_success
      payment_method = PaymentMethod.last
      expect(payment_method.details).to include(
        "brand" => "Visa",
        "last4" => "0000",
        "expiration_month" => "02",
        "expiration_year" => "26",
        "card_holder_name" => "Kevin Smith",
        "issuer" => "test"
      )
    end

    context "when event is card_token.updated" do
      let(:event_json) { JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/card_token.updated.json"))) }

      it "handles the event" do
        result = event_service.call

        expect(result).to be_success
        moneyhash_customer.reload
        expect(moneyhash_customer.payment_method_id).to eq(event_json.dig("data", "card_token", "id"))
      end

      it "updates card details in existing PaymentMethod.details" do
        result = event_service.call

        expect(result).to be_success
        payment_method = PaymentMethod.last
        expect(payment_method.details).to include("brand", "last4")
      end
    end

    context "when event is card_token.deleted" do
      let(:event_json) { JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/card_token.deleted.json"))) }
      let(:payment_method_id) { event_json.dig("data", "card_token", "id") }

      before { moneyhash_customer.update!(payment_method_id:) }

      it "handles the event" do
        result = event_service.call

        expect(result).to be_success
        moneyhash_customer.reload
        expect(moneyhash_customer.payment_method_id).to be_nil
      end

      context "when not the same card" do
        let(:payment_method_id) { "test_payment_id" }

        it "does not clear the default payment_method_id" do
          result = event_service.call

          expect(result).to be_success
          moneyhash_customer.reload
          expect(moneyhash_customer.payment_method_id).to eq("test_payment_id")
        end
      end

      context "when a PaymentMethod record exists" do
        let!(:payment_method) do
          create(
            :payment_method,
            customer:,
            payment_provider_customer: moneyhash_customer,
            provider_method_id: payment_method_id
          )
        end

        it "soft-deletes the PaymentMethod record" do
          expect { event_service.call }.to change { payment_method.reload.discarded? }.from(false).to(true)
        end
      end
    end
  end
end
