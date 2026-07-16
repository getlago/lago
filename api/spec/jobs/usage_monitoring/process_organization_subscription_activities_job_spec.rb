# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::ProcessOrganizationSubscriptionActivitiesJob do
  let(:organization) { create(:organization) }

  before do
    allow(UsageMonitoring::ProcessOrganizationSubscriptionActivitiesService).to receive(:call!)
  end

  context "when license is premium", :premium do
    it "calls the service with the organization" do
      described_class.perform_now(organization.id)
      expect(UsageMonitoring::ProcessOrganizationSubscriptionActivitiesService).to have_received(:call!).with(organization:)
    end
  end

  context "when license is not premium" do
    it "does not call the service or log" do
      described_class.perform_now(organization.id)
      expect(UsageMonitoring::ProcessOrganizationSubscriptionActivitiesService).not_to have_received(:call!)
    end
  end

  describe "queue routing" do
    let(:other_organization) { create(:organization) }

    before { stub_const("Utils::DedicatedWorkerConfig::ORGANIZATION_IDS", [organization.id]) }

    it "routes to the dedicated queue for a targeted organization" do
      job = described_class.new(organization.id)
      expect(job.queue_name).to eq("dedicated_alerts")
    end

    it "falls back to the default queue for non-targeted organizations" do
      job = described_class.new(other_organization.id)
      expect(job.queue_name).to eq("default")
    end
  end
end
