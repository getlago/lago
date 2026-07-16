# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Subscriptions::IncompleteService do
  subject(:webhook_service) { described_class.new(object: subscription) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, :incomplete, customer:, plan:, organization:) }

  describe ".call" do
    it_behaves_like "creates webhook", "subscription.incomplete", "subscription", {
      "lago_id" => String,
      "external_id" => String,
      "lago_customer_id" => String,
      "external_customer_id" => String,
      "plan_code" => String,
      "status" => "incomplete",
      "billing_time" => String,
      "started_at" => String,
      "created_at" => String,
      "customer" => Hash,
      "payment_method" => Hash
    }
  end
end
