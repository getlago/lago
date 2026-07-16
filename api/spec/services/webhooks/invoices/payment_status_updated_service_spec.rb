# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Invoices::PaymentStatusUpdatedService do
  subject(:webhook_service) { described_class.new(object: invoice) }

  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:subscription) { create(:subscription, organization:, customer:) }
  let(:invoice) { create(:invoice, customer:, organization:) }

  describe ".call" do
    it_behaves_like "creates webhook", "invoice.payment_status_updated", "invoice"
  end
end
