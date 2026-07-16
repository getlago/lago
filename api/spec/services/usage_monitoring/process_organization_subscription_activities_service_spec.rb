# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::ProcessOrganizationSubscriptionActivitiesService do
  describe "#call" do
    let(:organization) { create(:organization) }
    let(:service) { described_class.new(organization:) }

    it "enqueues jobs for subscription activities that are not yet enqueued" do
      create_list(:subscription_activity, 3, organization:, enqueued: false)
      create_list(:subscription_activity, 2, organization:, enqueued: true)

      result = nil
      expect { result = service.call }
        .to have_enqueued_job(UsageMonitoring::ProcessSubscriptionActivityJob).exactly(3).times

      expect(result).to be_success
      expect(result.nb_jobs_enqueued).to eq(3)
      expect(organization.subscription_activities.where(enqueued: true).count).to eq(5)
      expect(organization.subscription_activities.where(enqueued: false).count).to eq(0)
    end

    context "when there are no subscription activities to enqueue" do
      it "returns 0 for number of jobs enqueued and does not enqueue any job" do
        create_list(:subscription_activity, 2, organization:, enqueued: true)

        expect { service.call }
          .not_to have_enqueued_job(UsageMonitoring::ProcessSubscriptionActivityJob)

        result = service.call

        expect(result).to be_success
        expect(result.nb_jobs_enqueued).to eq(0)
      end
    end

    context "with more than BATCH_SIZE subscription activities" do
      let(:batch_size) { 3 }

      before do
        stub_const("#{described_class}::BATCH_SIZE", batch_size)
      end

      it "processes activities in batches" do
        create_list(:subscription_activity, batch_size + 1, organization:, enqueued: false)

        expect { service.call }
          .to have_enqueued_job(UsageMonitoring::ProcessSubscriptionActivityJob).exactly(batch_size + 1).times
      end
    end

    context "when the organization is targeted for the dedicated queue" do
      before { stub_const("Utils::DedicatedWorkerConfig::ORGANIZATION_IDS", [organization.id]) }

      it "enqueues ProcessSubscriptionActivityJob instances on the dedicated queue" do
        create_list(:subscription_activity, 2, organization:, enqueued: false)

        expect { service.call }
          .to have_enqueued_job(UsageMonitoring::ProcessSubscriptionActivityJob)
          .on_queue("dedicated_alerts").exactly(2).times
      end
    end

    context "when the organization is not targeted for the dedicated queue" do
      before { stub_const("Utils::DedicatedWorkerConfig::ORGANIZATION_IDS", []) }

      it "enqueues ProcessSubscriptionActivityJob instances on the default queue" do
        create_list(:subscription_activity, 2, organization:, enqueued: false)

        expect { service.call }
          .to have_enqueued_job(UsageMonitoring::ProcessSubscriptionActivityJob)
          .on_queue("default").exactly(2).times
      end
    end
  end
end
