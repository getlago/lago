# frozen_string_literal: true

require "rails_helper"

require "rake"

RSpec.describe "recipes:events:delete_in_range" do # rubocop:disable RSpec/DescribeClass
  let(:task) { Rake::Task["recipes:events:delete_in_range"] }

  let(:organization) { create(:organization) }
  let(:from_timestamp) { "2026-04-09 19:00:00" }
  let(:to_timestamp) { "2026-04-27 23:59:59" }

  before do
    Rake.application.rake_require("tasks/recipes/events")
    Rake::Task.define_task(:environment)
    task.reenable
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

  context "when organization uses clickhouse events store" do
    let(:organization) { create(:organization, clickhouse_events_store: true) }

    before { stub_stdin(organization.id, "y") }

    it "aborts" do
      expect { task.invoke }.to raise_error(SystemExit)
    end
  end

  context "when from_timestamp is after to_timestamp" do
    before { stub_stdin(organization.id, "y", "2026-04-28 00:00:00", "2026-04-27 00:00:00") }

    it "aborts" do
      expect { task.invoke }.to raise_error(SystemExit)
    end
  end

  context "when organization has no subscriptions" do
    before { stub_stdin(organization.id, "y", from_timestamp, to_timestamp) }

    it "finishes without deleting anything" do
      expect { task.invoke }.not_to raise_error
    end
  end

  context "when events exist in the time range" do
    let(:customer) { create(:customer, organization:) }
    let(:subscription) { create(:subscription, customer:, organization:) }

    let!(:event_in_range) do
      create(:event,
        organization_id: organization.id,
        subscription:,
        external_subscription_id: subscription.external_id,
        timestamp: Time.zone.parse("2026-04-10 12:00:00"))
    end

    let!(:event_out_of_range) do
      create(:event,
        organization_id: organization.id,
        subscription:,
        external_subscription_id: subscription.external_id,
        timestamp: Time.zone.parse("2026-04-01 12:00:00"))
    end

    context "when user confirms deletion" do
      before { stub_stdin(organization.id, "y", from_timestamp, to_timestamp, "y") }

      it "soft-deletes only events within the time range" do
        task.invoke

        expect(event_in_range.reload.deleted_at).to be_present
        expect(event_out_of_range.reload.deleted_at).to be_nil
      end
    end

    context "when user declines deletion" do
      before { stub_stdin(organization.id, "y", from_timestamp, to_timestamp, "n") }

      it "aborts without deleting events" do
        expect { task.invoke }.to raise_error(SystemExit)
        expect(event_in_range.reload.deleted_at).to be_nil
      end
    end

    context "when events span multiple subscriptions" do
      let(:other_subscription) { create(:subscription, customer:, organization:) }

      let!(:event_other_sub) do
        create(:event,
          organization_id: organization.id,
          subscription: other_subscription,
          external_subscription_id: other_subscription.external_id,
          timestamp: Time.zone.parse("2026-04-12 12:00:00"))
      end

      before { stub_stdin(organization.id, "y", from_timestamp, to_timestamp, "y") }

      it "soft-deletes events across all subscriptions" do
        task.invoke

        expect(event_in_range.reload.deleted_at).to be_present
        expect(event_other_sub.reload.deleted_at).to be_present
        expect(event_out_of_range.reload.deleted_at).to be_nil
      end
    end
  end
end
