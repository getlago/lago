# frozen_string_literal: true

require "rails_helper"

describe Clock::SubscriptionsToBeTerminatedJob, job: true do
  subject { described_class }

  it_behaves_like "a unique job" do
    let(:job_args) { [] }
  end

  describe ".perform" do
    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:) }
    let!(:webhook_endpoint) { create(:webhook_endpoint, organization:) }
    let(:current_date) { DateTime.parse("2026-06-01") }
    let(:ending_at_15_days) { (current_date + 15.days).beginning_of_day }
    let(:ending_at_45_days) { (current_date + 45.days).beginning_of_day }

    it "enqueues SendWebhookJob for subscriptions ending in 15 days" do
      subscription = create(:subscription, customer:, organization:, ending_at: ending_at_15_days)
      create(:subscription, customer:, organization:, ending_at: ending_at_15_days + 1.year)

      travel_to(current_date) do
        described_class.perform_now

        expect(SendWebhookJob).to have_been_enqueued
          .with("subscription.termination_alert", subscription)
          .exactly(:once)
      end
    end

    it "enqueues SendWebhookJob for subscriptions ending in 45 days" do
      subscription = create(:subscription, customer:, organization:, ending_at: ending_at_45_days)

      travel_to(current_date) do
        described_class.perform_now

        expect(SendWebhookJob).to have_been_enqueued
          .with("subscription.termination_alert", subscription)
          .exactly(:once)
      end
    end

    it "does not enqueue for subscriptions without ending_at" do
      create(:subscription, customer:, organization:, ending_at: nil)

      travel_to(current_date) do
        described_class.perform_now

        expect(SendWebhookJob).not_to have_been_enqueued
          .with("subscription.termination_alert", anything)
      end
    end

    it "does not enqueue for subscriptions with non-matching ending_at" do
      create(:subscription, customer:, organization:, ending_at: current_date + 10.days)

      travel_to(current_date) do
        described_class.perform_now

        expect(SendWebhookJob).not_to have_been_enqueued
          .with("subscription.termination_alert", anything)
      end
    end

    context "with non-active subscriptions" do
      it "does not enqueue for pending subscriptions" do
        create(:subscription, :pending, customer:, organization:, ending_at: ending_at_15_days)

        travel_to(current_date) do
          described_class.perform_now

          expect(SendWebhookJob).not_to have_been_enqueued
            .with("subscription.termination_alert", anything)
        end
      end

      it "does not enqueue for terminated subscriptions" do
        create(:subscription, :terminated, customer:, organization:, ending_at: ending_at_15_days)

        travel_to(current_date) do
          described_class.perform_now

          expect(SendWebhookJob).not_to have_been_enqueued
            .with("subscription.termination_alert", anything)
        end
      end

      it "does not enqueue for canceled subscriptions" do
        create(:subscription, :canceled, customer:, organization:, ending_at: ending_at_15_days)

        travel_to(current_date) do
          described_class.perform_now

          expect(SendWebhookJob).not_to have_been_enqueued
            .with("subscription.termination_alert", anything)
        end
      end
    end

    context "with multiple matching subscriptions at different windows" do
      it "enqueues for both subscriptions" do
        sub_15 = create(:subscription, customer:, organization:, ending_at: ending_at_15_days)
        sub_45 = create(:subscription, customer:, organization:, ending_at: ending_at_45_days)

        travel_to(current_date) do
          described_class.perform_now

          expect(SendWebhookJob).to have_been_enqueued
            .with("subscription.termination_alert", sub_15)
          expect(SendWebhookJob).to have_been_enqueued
            .with("subscription.termination_alert", sub_45)
        end
      end
    end

    context "when termination_alert webhook was already sent today" do
      it "does not enqueue" do
        subscription = create(:subscription, customer:, organization:, ending_at: ending_at_15_days)

        travel_to(current_date) do
          create(
            :webhook,
            :succeeded,
            webhook_endpoint:,
            object: subscription,
            webhook_type: "subscription.termination_alert",
            created_at: current_date
          )

          described_class.perform_now

          expect(SendWebhookJob).not_to have_been_enqueued
            .with("subscription.termination_alert", anything)
        end
      end
    end

    context "when termination_alert webhook was sent yesterday" do
      it "enqueues the alert" do
        subscription = create(:subscription, customer:, organization:, ending_at: ending_at_15_days)
        create(
          :webhook,
          :succeeded,
          webhook_endpoint:,
          object: subscription,
          webhook_type: "subscription.termination_alert",
          created_at: current_date - 1.day
        )

        travel_to(current_date) do
          described_class.perform_now

          expect(SendWebhookJob).to have_been_enqueued
            .with("subscription.termination_alert", subscription)
            .exactly(:once)
        end
      end
    end

    context "when termination_alert webhook was sent 30 days ago" do
      it "enqueues the alert" do
        subscription = create(:subscription, customer:, organization:, ending_at: ending_at_15_days)
        create(
          :webhook,
          :succeeded,
          webhook_endpoint:,
          object: subscription,
          webhook_type: "subscription.termination_alert",
          created_at: current_date - 30.days
        )

        travel_to(current_date) do
          described_class.perform_now

          expect(SendWebhookJob).to have_been_enqueued
            .with("subscription.termination_alert", subscription)
            .exactly(:once)
        end
      end
    end

    context "when a different webhook type was sent today" do
      it "still enqueues the termination alert" do
        subscription = create(:subscription, customer:, organization:, ending_at: ending_at_15_days)

        travel_to(current_date) do
          create(
            :webhook,
            :succeeded,
            webhook_endpoint:,
            object: subscription,
            webhook_type: "subscription.started",
            created_at: current_date
          )

          described_class.perform_now

          expect(SendWebhookJob).to have_been_enqueued
            .with("subscription.termination_alert", subscription)
            .exactly(:once)
        end
      end
    end

    context "when a pending termination_alert webhook exists for today" do
      it "does not enqueue" do
        subscription = create(:subscription, customer:, organization:, ending_at: ending_at_15_days)

        travel_to(current_date) do
          create(
            :webhook,
            :pending,
            webhook_endpoint:,
            object: subscription,
            webhook_type: "subscription.termination_alert",
            created_at: current_date
          )

          described_class.perform_now

          expect(SendWebhookJob).not_to have_been_enqueued
            .with("subscription.termination_alert", anything)
        end
      end
    end

    context "when a failed termination_alert webhook exists for today" do
      it "does not enqueue" do
        subscription = create(:subscription, customer:, organization:, ending_at: ending_at_15_days)

        travel_to(current_date) do
          create(
            :webhook,
            :failed,
            webhook_endpoint:,
            object: subscription,
            webhook_type: "subscription.termination_alert",
            created_at: current_date
          )

          described_class.perform_now

          expect(SendWebhookJob).not_to have_been_enqueued
            .with("subscription.termination_alert", anything)
        end
      end
    end

    context "with multiple webhook endpoints having webhooks today" do
      it "does not enqueue" do
        subscription = create(:subscription, customer:, organization:, ending_at: ending_at_15_days)
        webhook_endpoint2 = create(:webhook_endpoint, organization:)

        travel_to(current_date) do
          create(
            :webhook,
            :succeeded,
            webhook_endpoint:,
            object: subscription,
            webhook_type: "subscription.termination_alert",
            created_at: current_date
          )
          create(
            :webhook,
            :succeeded,
            webhook_endpoint: webhook_endpoint2,
            object: subscription,
            webhook_type: "subscription.termination_alert",
            created_at: current_date
          )

          described_class.perform_now

          expect(SendWebhookJob).not_to have_been_enqueued
            .with("subscription.termination_alert", anything)
        end
      end
    end

    context "with multiple webhook endpoints having webhooks from a past day" do
      it "enqueues exactly once" do
        subscription = create(:subscription, customer:, organization:, ending_at: ending_at_15_days)
        webhook_endpoint2 = create(:webhook_endpoint, organization:)
        create(
          :webhook,
          :succeeded,
          webhook_endpoint:,
          object: subscription,
          webhook_type: "subscription.termination_alert",
          created_at: current_date - 30.days
        )
        create(
          :webhook,
          :succeeded,
          webhook_endpoint: webhook_endpoint2,
          object: subscription,
          webhook_type: "subscription.termination_alert",
          created_at: current_date - 30.days
        )

        travel_to(current_date) do
          described_class.perform_now

          expect(SendWebhookJob).to have_been_enqueued
            .with("subscription.termination_alert", subscription)
            .exactly(:once)
        end
      end
    end

    context "when ending_at is at end of day" do
      it "still enqueues the alert" do
        subscription = create(:subscription, customer:, organization:, ending_at: ending_at_15_days.end_of_day)

        travel_to(current_date) do
          described_class.perform_now

          expect(SendWebhookJob).to have_been_enqueued
            .with("subscription.termination_alert", subscription)
            .exactly(:once)
        end
      end
    end

    context "with subscriptions from different organizations" do
      it "enqueues for matching subscriptions across organizations" do
        other_org = create(:organization)
        other_customer = create(:customer, organization: other_org)
        create(:webhook_endpoint, organization: other_org)
        other_sub = create(:subscription, customer: other_customer, organization: other_org, ending_at: ending_at_15_days)
        sub = create(:subscription, customer:, organization:, ending_at: ending_at_15_days)

        travel_to(current_date) do
          described_class.perform_now

          expect(SendWebhookJob).to have_been_enqueued
            .with("subscription.termination_alert", sub)
          expect(SendWebhookJob).to have_been_enqueued
            .with("subscription.termination_alert", other_sub)
        end
      end
    end

    context "when a termination_alert webhook exists with a different object_type" do
      it "does not block the alert" do
        subscription = create(:subscription, customer:, organization:, ending_at: ending_at_15_days)

        travel_to(current_date) do
          webhook = create(
            :webhook,
            :succeeded,
            webhook_endpoint:,
            object: subscription,
            webhook_type: "subscription.termination_alert",
            created_at: current_date
          )
          webhook.update_column(:object_type, "Invoice") # rubocop:disable Rails/SkipsModelValidations

          described_class.perform_now

          expect(SendWebhookJob).to have_been_enqueued
            .with("subscription.termination_alert", subscription)
            .exactly(:once)
        end
      end
    end

    describe "index usage" do
      # Force PostgreSQL to use indexes even on a tiny test dataset so we can
      # verify the planner CAN use them for the query patterns the job produces.
      around do |example|
        ActiveRecord::Base.connection.execute("SET enable_seqscan = off")
        example.run
      ensure
        ActiveRecord::Base.connection.execute("SET enable_seqscan = on")
      end

      it "uses the partial index on ending_at for the subscription lookup" do
        create(:subscription, customer:, organization:, ending_at: ending_at_15_days)

        plan = travel_to(current_date) do
          Subscription
            .active
            .where("DATE(ending_at::timestamptz) IN (?)", [ending_at_15_days.to_date])
            .explain
            .inspect
        end

        expect(plan).to include("index_subscriptions_on_ending_at_active")
      end

      it "uses the composite index on (object_type, object_id, webhook_type) for the webhook dedup" do
        subscription = create(:subscription, customer:, organization:, ending_at: ending_at_15_days)

        plan = travel_to(current_date) do
          Webhook
            .where(
              webhook_type: "subscription.termination_alert",
              object_type: "Subscription",
              object_id: [subscription.id]
            )
            .where("created_at::date = ?", current_date.to_date)
            .explain
            .inspect
        end

        expect(plan).to include("index_webhooks_on_object_type_and_object_id_and_webhook_type")
      end
    end

    context "with custom LAGO_SUBSCRIPTION_TERMINATION_ALERT_SENT_AT_DAYS" do
      around do |test|
        old_value = ENV["LAGO_SUBSCRIPTION_TERMINATION_ALERT_SENT_AT_DAYS"]
        ENV["LAGO_SUBSCRIPTION_TERMINATION_ALERT_SENT_AT_DAYS"] = "1,15,45"
        test.run
      ensure
        if old_value
          ENV["LAGO_SUBSCRIPTION_TERMINATION_ALERT_SENT_AT_DAYS"] = old_value
        else
          ENV.delete("LAGO_SUBSCRIPTION_TERMINATION_ALERT_SENT_AT_DAYS")
        end
      end

      it "uses custom day intervals" do
        ending_at_1_day = (current_date + 1.day).beginning_of_day
        sub_1 = create(:subscription, customer:, organization:, ending_at: ending_at_1_day)
        sub_15 = create(:subscription, customer:, organization:, ending_at: ending_at_15_days)
        sub_45 = create(:subscription, customer:, organization:, ending_at: ending_at_45_days)

        travel_to(current_date) do
          described_class.perform_now

          expect(SendWebhookJob).to have_been_enqueued
            .with("subscription.termination_alert", sub_1)
          expect(SendWebhookJob).to have_been_enqueued
            .with("subscription.termination_alert", sub_15)
          expect(SendWebhookJob).to have_been_enqueued
            .with("subscription.termination_alert", sub_45)
        end
      end

      it "does not enqueue for default-only intervals not in custom config" do
        # 15 and 45 are in custom config, but 30 is not
        ending_at_30_days = (current_date + 30.days).beginning_of_day
        create(:subscription, customer:, organization:, ending_at: ending_at_30_days)

        travel_to(current_date) do
          described_class.perform_now

          expect(SendWebhookJob).not_to have_been_enqueued
            .with("subscription.termination_alert", anything)
        end
      end
    end
  end
end
