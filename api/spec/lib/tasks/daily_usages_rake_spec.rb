# frozen_string_literal: true

require "rails_helper"

require "rake"

RSpec.describe "daily_usages:fill_history" do # rubocop:disable RSpec/DescribeClass
  let(:task) { Rake::Task["daily_usages:fill_history"] }
  let(:organization) { create(:organization, api_keys: []) }

  before do
    Rake.application.rake_require("tasks/daily_usages")
    Rake::Task.define_task(:environment)
    task.reenable

    allow(DailyUsages::FillHistoryJob).to receive(:perform_later)
  end

  def stub_stdin(*responses)
    allow($stdin).to receive(:gets).and_return(*responses.map { |r| "#{r}\n" })
  end

  context "when organization is not found" do
    before { stub_stdin("00000000") }

    it "aborts" do
      expect { task.invoke }.to raise_error(SystemExit)
    end
  end

  context "when user does not confirm the organization" do
    before { stub_stdin(organization.id, "n") }

    it "aborts" do
      expect { task.invoke }.to raise_error(SystemExit)
    end
  end

  context "when organization has no subscriptions in scope" do
    before { stub_stdin(organization.id, "y", "", "") }

    it "finishes without enqueueing any job" do
      expect { task.invoke }.not_to raise_error
      expect(DailyUsages::FillHistoryJob).not_to have_received(:perform_later)
    end
  end

  context "when organization has subscriptions in scope" do
    let(:customer) { create(:customer, organization:) }
    let!(:active_sub) { create(:subscription, customer:, organization:) }
    let!(:terminated_sub) do
      create(:subscription, :terminated, customer:, organization:, terminated_at: Time.current)
    end
    let!(:pending_sub) { create(:subscription, :pending, customer:, organization:) }

    let!(:existing_usage) do
      create(:daily_usage, organization:, customer:, subscription: active_sub, usage_date: Date.current)
    end

    context "when user confirms deletion with the default date" do
      before { stub_stdin(organization.id, "y", "", "", "y", "y") }

      it "deletes existing daily_usages in scope" do
        task.invoke
        expect(DailyUsage.where(id: existing_usage.id)).not_to exist
      end

      it "enqueues a FillHistoryJob for active and terminated subscriptions" do
        task.invoke
        expect(DailyUsages::FillHistoryJob).to have_received(:perform_later)
          .with(subscription: active_sub, from_date: DailyUsage::DEFAULT_HISTORY_DAYS.days.ago.to_date)
        expect(DailyUsages::FillHistoryJob).to have_received(:perform_later)
          .with(subscription: terminated_sub, from_date: DailyUsage::DEFAULT_HISTORY_DAYS.days.ago.to_date)
      end

      it "does not enqueue a job for pending subscriptions" do
        task.invoke
        expect(DailyUsages::FillHistoryJob).not_to have_received(:perform_later)
          .with(subscription: pending_sub, from_date: anything)
      end
    end

    context "when user declines deletion but continues" do
      before { stub_stdin(organization.id, "y", "", "", "n", "y") }

      it "keeps existing daily_usages" do
        task.invoke
        expect(DailyUsage.where(id: existing_usage.id)).to exist
      end

      it "still enqueues the FillHistoryJobs" do
        task.invoke
        expect(DailyUsages::FillHistoryJob).to have_received(:perform_later)
          .with(subscription: active_sub, from_date: DailyUsage::DEFAULT_HISTORY_DAYS.days.ago.to_date)
      end
    end

    context "when user enters a custom date" do
      before { stub_stdin(organization.id, "y", "", "2026-01-15", "y", "y") }

      it "uses the entered date as from_date" do
        task.invoke
        expect(DailyUsages::FillHistoryJob).to have_received(:perform_later)
          .with(subscription: active_sub, from_date: Date.new(2026, 1, 15))
      end
    end

    context "when user enters an invalid date" do
      before { stub_stdin(organization.id, "y", "", "not-a-date") }

      it "aborts" do
        expect { task.invoke }.to raise_error(SystemExit)
        expect(DailyUsages::FillHistoryJob).not_to have_received(:perform_later)
      end
    end

    context "when user declines the final confirmation" do
      before { stub_stdin(organization.id, "y", "", "", "y", "n") }

      it "aborts without deleting or enqueueing" do
        expect { task.invoke }.to raise_error(SystemExit)
        expect(DailyUsage.where(id: existing_usage.id)).to exist
        expect(DailyUsages::FillHistoryJob).not_to have_received(:perform_later)
      end
    end

    context "when a subscription list is provided" do
      before { stub_stdin(organization.id, "y", active_sub.id, "", "y", "y") }

      it "only enqueues a FillHistoryJob for the provided subscriptions" do
        task.invoke
        expect(DailyUsages::FillHistoryJob).to have_received(:perform_later)
          .with(subscription: active_sub, from_date: DailyUsage::DEFAULT_HISTORY_DAYS.days.ago.to_date)
        expect(DailyUsages::FillHistoryJob).not_to have_received(:perform_later)
          .with(subscription: terminated_sub, from_date: anything)
      end
    end

    context "when multiple subscription ids are provided" do
      before { stub_stdin(organization.id, "y", "#{active_sub.id}, #{terminated_sub.id}", "", "y", "y") }

      it "enqueues a FillHistoryJob for each provided subscription" do
        task.invoke
        expect(DailyUsages::FillHistoryJob).to have_received(:perform_later)
          .with(subscription: active_sub, from_date: DailyUsage::DEFAULT_HISTORY_DAYS.days.ago.to_date)
        expect(DailyUsages::FillHistoryJob).to have_received(:perform_later)
          .with(subscription: terminated_sub, from_date: DailyUsage::DEFAULT_HISTORY_DAYS.days.ago.to_date)
        expect(DailyUsages::FillHistoryJob).not_to have_received(:perform_later)
          .with(subscription: pending_sub, from_date: anything)
      end
    end
  end
end
