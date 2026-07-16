# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Subscriptions::CanceledService do
  subject(:webhook_service) { described_class.new(object: subscription) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, :canceled, customer:, plan:, organization:) }

  describe ".call" do
    it_behaves_like "creates webhook", "subscription.canceled", "subscription", {
      "lago_id" => String,
      "external_id" => String,
      "lago_customer_id" => String,
      "external_customer_id" => String,
      "plan_code" => String,
      "status" => "canceled",
      "billing_time" => String,
      "created_at" => String,
      "customer" => Hash,
      "payment_method" => Hash
    }
  end
end
