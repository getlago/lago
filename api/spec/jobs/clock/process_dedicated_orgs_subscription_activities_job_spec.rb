# frozen_string_literal: true

require "rails_helper"

RSpec.describe Clock::ProcessDedicatedOrgsSubscriptionActivitiesJob, job: true do
  describe "#perform" do
    subject { described_class.perform_now }

    let(:target_organization) { create(:organization) }
    let(:other_organization) { create(:organization) }

    context "when the dedicated org list is empty" do
      before { stub_const("Utils::DedicatedWorkerConfig::ORGANIZATION_IDS", []) }

      context "when premium", :premium do
        it "does not enqueue any job" do
          subject
          expect(UsageMonitoring::ProcessOrganizationSubscriptionActivitiesJob).not_to have_been_enqueued
        end
      end
    end

    context "when the dedicated org list contains the target organization" do
      before { stub_const("Utils::DedicatedWorkerConfig::ORGANIZATION_IDS", [target_organization.id]) }

      context "when freemium" do
        it "does not enqueue any job" do
          create(:subscription_activity, organization: target_organization, enqueued: false)

          subject

          expect(UsageMonitoring::ProcessOrganizationSubscriptionActivitiesJob).not_to have_been_enqueued
        end
      end

      context "when premium", :premium do
        context "when the target org has pending subscription activities" do
          before do
            create(:subscription_activity, organization: target_organization, enqueued: false)
            create(:subscription_activity, organization: other_organization, enqueued: false)
          end

          it "enqueues ProcessOrganizationSubscriptionActivitiesJob for target org only" do
            subject
            expect(UsageMonitoring::ProcessOrganizationSubscriptionActivitiesJob).to have_been_enqueued.with(target_organization.id).once
            expect(UsageMonitoring::ProcessOrganizationSubscriptionActivitiesJob).not_to have_been_enqueued.with(other_organization.id)
          end
        end

        context "when the target org has no pending subscription activities" do
          it "does not enqueue a job" do
            subject
            expect(UsageMonitoring::ProcessOrganizationSubscriptionActivitiesJob).not_to have_been_enqueued
          end
        end

        context "when the target org only has activities already enqueued" do
          before { create(:subscription_activity, organization: target_organization, enqueued: true) }

          it "does not enqueue a job" do
            subject
            expect(UsageMonitoring::ProcessOrganizationSubscriptionActivitiesJob).not_to have_been_enqueued
          end
        end
      end
    end
  end
end
