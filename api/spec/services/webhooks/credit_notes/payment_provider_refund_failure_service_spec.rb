# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::CreditNotes::PaymentProviderRefundFailureService do
  subject(:webhook_service) { described_class.new(object: credit_note, options: webhook_options) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, organization:, customer:) }
  let(:credit_note) { create(:credit_note, customer:, invoice:) }
  let(:webhook_options) { {provider_error: {message: "message", error_code: "code"}} }

  describe ".call" do
    it_behaves_like "creates webhook", "credit_note.refund_failure", "credit_note_payment_provider_refund_error"
  end
end
