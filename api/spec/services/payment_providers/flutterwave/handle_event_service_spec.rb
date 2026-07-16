# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Flutterwave::HandleEventService do
  subject(:handle_event_service) { described_class.new(organization:, event_json:) }

  let(:organization) { create(:organization) }
  let(:event_json) { payload.to_json }

  let(:payload) do
    {
      event: "charge.completed",
      data: {
        id: 123456,
        status: "successful",
        amount: 100.0,
        currency: "USD",
        tx_ref: "lago_invoice_12345",
        meta: {
          lago_invoice_id: "12345",
          lago_payable_type: "Invoice"
        }
      }
    }
  end

  describe "#call" do
    context "when event is charge.completed" do
      it "calls the charge completed service" do
        allow(PaymentProviders::Flutterwave::Webhooks::ChargeCompletedService)
          .to receive(:call!)

        result = handle_event_service.call

        expect(PaymentProviders::Flutterwave::Webhooks::ChargeCompletedService)
          .to have_received(:call!)
          .with(organization_id: organization.id, event_json:)
        expect(result).to be_success
      end

      it "returns success even if the service raises an error" do
        allow(PaymentProviders::Flutterwave::Webhooks::ChargeCompletedService)
          .to receive(:call!).and_raise(StandardError.new("Service error"))

        expect { handle_event_service.call }.not_to raise_error
      end
    end

    context "when event is not supported" do
      let(:payload) do
        {
          event: "charge.failed",
          data: {}
        }
      end

      it "does not call any webhook service" do
        allow(PaymentProviders::Flutterwave::Webhooks::ChargeCompletedService)
          .to receive(:call!)

        result = handle_event_service.call

        expect(PaymentProviders::Flutterwave::Webhooks::ChargeCompletedService)
          .not_to have_received(:call!)
        expect(result).to be_success
      end
    end

    context "when event_json is invalid JSON" do
      let(:event_json) { "invalid json" }

      it "raises a JSON parse error" do
        expect { handle_event_service.call }.to raise_error(JSON::ParserError)
      end
    end

    context "when event key is missing" do
      let(:payload) do
        {
          data: {}
        }
      end

      it "does not call any webhook service" do
        allow(PaymentProviders::Flutterwave::Webhooks::ChargeCompletedService)
          .to receive(:call!)

        result = handle_event_service.call

        expect(PaymentProviders::Flutterwave::Webhooks::ChargeCompletedService)
          .not_to have_received(:call!)
        expect(result).to be_success
      end
    end
  end
end
