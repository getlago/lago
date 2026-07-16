# frozen_string_literal: true

require "rails_helper"

describe "Invoice Email Activity Logging", :capture_kafka_messages do
  let(:email) { "customer@example.com" }
  let(:email_settings) { ["invoice.finalized"] }
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:plan) { create(:plan, organization:, pay_in_advance: true) }
  let(:customer) { create(:customer, organization:, email:) }
  let(:email_messages) { kafka_messages.select { |msg| JSON.parse(msg[:payload])["activity_type"] == "email.sent" } }

  before do
    # Create a pay-in-advance subscription which generates and finalizes an invoice immediately
    Subscriptions::CreateService.call(customer:, plan:, params: {external_id: SecureRandom.uuid})

    # Enable email scenario for the billing entity
    organization.default_billing_entity.tap { |be| be.update!(email:, email_settings:) }

    # Enable activity logging (requires Kafka/ClickHouse in production)
    stub_const("Utils::EmailActivityLog::AVAILABLE", true)
    stub_const("Utils::EmailActivityLog::TOPIC", "activity_logs")

    perform_all_enqueued_jobs
  end

  # Pretend License is premium for these tests
  around do |example|
    old_premium = License.premium?
    License.instance_variable_set(:@premium, true)
    example.run
  ensure
    License.instance_variable_set(:@premium, old_premium)
  end

  context "when invoice is finalized" do
    it "logs email activity to Kafka" do
      expect(email_messages.size).to eq(1)

      payload = JSON.parse(email_messages.first[:payload])
      expect(payload).to include(
        "activity_type" => "email.sent",
        "activity_source" => "system",
        "resource_type" => "Invoice"
      )
    end
  end

  context "when email scenario is disabled" do
    let(:email_settings) { [] }

    it "does not log email activity" do
      expect(email_messages).to be_empty
    end
  end

  context "when customer has no email" do
    let(:email) { nil }

    it "does not log email activity" do
      expect(email_messages).to be_empty
    end
  end

  context "when License is not premium" do
    around do |example|
      License.instance_variable_set(:@premium, false)
      example.run
    end

    it "does not log email activity" do
      expect(email_messages).to be_empty
    end
  end
end
