# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::PaymentReceipts::GeneratedService do
  subject(:webhook_service) { described_class.new(object: payment_receipt) }

  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, organization:, customer:) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:payment) { create(:payment, payable: invoice) }
  let(:payment_receipt) { create(:payment_receipt, payment:) }
  let(:organization) { create(:organization) }

  describe ".call" do
    it_behaves_like "creates webhook", "payment_receipt.generated", "payment_receipt", {"payment" => Hash}
  end
end
