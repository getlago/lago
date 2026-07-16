# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::PaymentRequests::CreatedService do
  subject(:webhook_service) { described_class.new(object: payment_request) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:payment_request) { create(:payment_request, customer:, organization:) }

  describe ".call" do
    it_behaves_like "creates webhook", "payment_request.created", "payment_request", {"customer" => Hash, "invoices" => Array}
  end
end
