# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Payments::SucceededService do
  subject(:webhook_service) { described_class.new(object: payment) }

  let(:payment) do
    create(
      :payment,
      payable_payment_status: :succeeded,
      payment_method: payment_method
    )
  end
  let(:payment_method) { create(:payment_method) }

  it_behaves_like "creates webhook", "payment.succeeded", "payment", {
    "lago_id" => String,
    "lago_payable_id" => String,
    "payable_type" => String,
    "payment_provider_code" => String,
    "provider_payment_id" => String,
    "payment_method" => Hash
  }
end
