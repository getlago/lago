# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::PaymentReceipts::CreatedService do
  subject(:webhook_service) { described_class.new(object: payment_receipt) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:payment) { create(:payment, payable: invoice) }
  let(:payment_receipt) { create(:payment_receipt, payment:) }

  describe ".call" do
    it_behaves_like "creates webhook", "payment_receipt.created", "payment_receipt", {"payment" => Hash}
  end
end
