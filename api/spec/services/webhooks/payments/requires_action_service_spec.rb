# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Payments::RequiresActionService do
  subject(:webhook_service) { described_class.new(object: payment, options: webhook_options) }

  let(:payment) { create(:payment, :requires_action) }
  let(:webhook_options) { {provider_customer_id: "customer_id"} }

  it_behaves_like "creates webhook", "payment.requires_action", "payment", {
    "lago_id" => String,
    "lago_payable_id" => String,
    "payable_type" => String,
    "payment_provider_code" => String,
    "provider_payment_id" => String,
    "next_action" => Hash
  }
end
