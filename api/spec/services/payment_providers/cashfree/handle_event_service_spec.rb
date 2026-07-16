# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Cashfree::HandleEventService do
  subject(:event_service) { described_class.new(organization:, event_json:) }

  let(:organization) { create(:organization) }

  let(:payment_service) { instance_double(Invoices::Payments::CashfreeService) }
  let(:service_result) { BaseService::Result.new }

  let(:event_json) do
    path = Rails.root.join("spec/fixtures/cashfree/payment_link_event_payment.json")
    File.read(path)
  end

  describe ".call" do
    let(:event_json) do
      path = Rails.root.join("spec/fixtures/cashfree/payment_link_event_payment_request.json")
      File.read(path)
    end

    before do
      allow(PaymentProviders::Cashfree::Webhooks::PaymentLinkEventService).to receive(:call)
        .and_return(service_result)
    end

    it "routes the event to an other service" do
      expect(event_service.call).to be_success
      expect(PaymentProviders::Cashfree::Webhooks::PaymentLinkEventService).to have_received(:call)
    end
  end
end
