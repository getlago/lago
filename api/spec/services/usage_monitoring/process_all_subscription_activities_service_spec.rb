# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::ProcessAllSubscriptionActivitiesService do
  describe "#call" do
    subject(:service) { described_class.new }

    before do
      allow(UsageMonitoring::ProcessOrganizationSubscriptionActivitiesJob).to receive(:perform_later)
      allow(Rails.logger).to receive(:info)
    end

    it "enqueues ProcessOrganizationSubscriptionActivitiesJob for organizations with SubscriptionActivity" do
      organization1 = create(:organization, premium_integrations: [])
      organization2 = create(:organization, premium_integrations: ["progressive_billing"])
      organization3 = create(:organization, premium_integrations: ["salesforce"])
      create_list(:subscription_activity, 2, organization: organization1)
      create_list(:subscription_activity, 3, organization: organization2)

      result = service.call

      expect(result).to be_success
      expect(UsageMonitoring::ProcessOrganizationSubscriptionActivitiesJob).to have_received(:perform_later).with(organization1.id)
      expect(UsageMonitoring::ProcessOrganizationSubscriptionActivitiesJob).to have_received(:perform_later).with(organization2.id)
      expect(UsageMonitoring::ProcessOrganizationSubscriptionActivitiesJob).not_to have_received(:perform_later).with(organization3.id)
    end

    context "when some organizations are targeted for the dedicated queue" do
      let(:dedicated_organization) { create(:organization) }
      let(:other_organization) { create(:organization) }

      before do
        stub_const("Utils::DedicatedWorkerConfig::ORGANIZATION_IDS", [dedicated_organization.id])
        create_list(:subscription_activity, 2, organization: dedicated_organization)
        create_list(:subscription_activity, 1, organization: other_organization)
      end

      it "skips dedicated organizations and enqueues only the others" do
        service.call

        expect(UsageMonitoring::ProcessOrganizationSubscriptionActivitiesJob).to have_received(:perform_later).with(other_organization.id)
        expect(UsageMonitoring::ProcessOrganizationSubscriptionActivitiesJob).not_to have_received(:perform_later).with(dedicated_organization.id)
      end
    end
  end
end
