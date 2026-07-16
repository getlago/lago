# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::PaymentRequests::PaymentStatusUpdatedService do
  subject(:webhook_service) { described_class.new(object: payment_request) }

  let(:payment_request) { create(:payment_request) }

  describe ".call" do
    it_behaves_like "creates webhook", "payment_request.payment_status_updated", "payment_request"
  end
end
