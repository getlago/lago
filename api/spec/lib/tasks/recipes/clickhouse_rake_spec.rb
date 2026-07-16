# frozen_string_literal: true

require "rails_helper"

require "rake"

RSpec.describe "recipes:clickhouse:enable_clickhouse_events_store", clickhouse: true do # rubocop:disable RSpec/DescribeClass
  let(:task) { Rake::Task["recipes:clickhouse:enable_clickhouse_events_store"] }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:, organization:) }
  let(:timestamp) { Time.current.beginning_of_hour - 1.hour }

  before do
    Rake.application.rake_require("tasks/recipes/clickhouse")
    Rake::Task.define_task(:environment)
    task.reenable

    ::Clickhouse::EventsEnriched.connection.execute("TRUNCATE TABLE events_enriched")
  end

  def stub_stdin(*responses)
    allow($stdin).to receive(:gets).and_return(*responses.map { |r| "#{r}\n" })
  end

  def stub_usage(*amount_cents_per_call)
    stub = allow(Invoices::CustomerUsageService).to receive(:call)
    return if amount_cents_per_call.empty?

    results = amount_cents_per_call.map do |cents|
      fees = cents.nil? ? [] : [Fee.new(amount_cents: cents)]
      BaseService::LegacyResult.new.tap { |r| r.usage = SubscriptionUsage.new(fees:) }
    end
    stub.and_return(*results)
  end

  context "when organization is not found" do
    before { stub_stdin("00000000") }

    it "aborts" do
      expect { task.invoke }.to raise_error(SystemExit)
    end
  end

  context "when organization already uses ClickHouse events store" do
    let(:organization) { create(:organization, clickhouse_events_store: true) }

    before { stub_stdin(organization.id, "y") }

    it "aborts" do
      expect { task.invoke }.to raise_error(SystemExit)
    end
  end

  context "when Postgres and ClickHouse counts do not match" do
    before do
      create(:event,
        organization_id: organization.id,
        subscription:,
        external_subscription_id: subscription.external_id,
        timestamp:)

      stub_stdin(organization.id, "y", "")
    end

    it "aborts" do
      expect { task.invoke }.to raise_error(SystemExit)
      expect(organization.reload.clickhouse_events_store).to be(false)
    end
  end

  context "when ClickHouse has events with enrichment issues" do
    before do
      create(:event,
        organization_id: organization.id,
        subscription:,
        external_subscription_id: subscription.external_id,
        timestamp:)

      create(:clickhouse_events_enriched,
        organization_id: organization.id,
        external_subscription_id: subscription.external_id,
        timestamp:,
        value: "<nil>")

      stub_stdin(organization.id, "y", "")
    end

    it "aborts" do
      expect { task.invoke }.to raise_error(SystemExit)
      expect(organization.reload.clickhouse_events_store).to be(false)
    end
  end

  context "when counts match and no enrichment issues" do
    before do
      allow(ApiKeys::CacheService).to receive(:expire_all_cache)
      stub_usage(1000, 1000)

      create(:event,
        organization_id: organization.id,
        subscription:,
        external_subscription_id: subscription.external_id,
        timestamp:)

      create(:clickhouse_events_enriched,
        organization_id: organization.id,
        external_subscription_id: subscription.external_id,
        timestamp:)
    end

    context "when user confirms" do
      before { stub_stdin(organization.id, "y", "", "y") }

      it "enables ClickHouse events store and expires the API key cache" do
        task.invoke

        organization.reload
        expect(organization.clickhouse_events_store).to be(true)
        expect(organization.clickhouse_deduplication_enabled).to be(true)
        expect(ApiKeys::CacheService).to have_received(:expire_all_cache).with(organization)
      end
    end

    context "when user declines the final confirmation" do
      before { stub_stdin(organization.id, "y", "", "n") }

      it "aborts without updating the organization" do
        expect { task.invoke }.to raise_error(SystemExit)
        expect(organization.reload.clickhouse_events_store).to be(false)
      end
    end
  end

  context "when ClickHouse has duplicate rows for the same logical event" do
    let(:transaction_id) { "tr_#{SecureRandom.hex}" }
    let(:code) { "event_code" }

    before do
      allow(ApiKeys::CacheService).to receive(:expire_all_cache)
      stub_usage(1000, 1000)

      create(:event,
        organization_id: organization.id,
        subscription:,
        external_subscription_id: subscription.external_id,
        transaction_id:,
        code:,
        timestamp:)

      2.times do
        create(:clickhouse_events_enriched,
          organization_id: organization.id,
          external_subscription_id: subscription.external_id,
          transaction_id:,
          code:,
          timestamp:)
      end

      stub_stdin(organization.id, "y", "", "y")
    end

    it "deduplicates ClickHouse rows and enables the store" do
      task.invoke

      expect(organization.reload.clickhouse_events_store).to be(true)
    end
  end

  context "with usage comparison step" do
    before do
      allow(ApiKeys::CacheService).to receive(:expire_all_cache)

      create(:event,
        organization_id: organization.id,
        subscription:,
        external_subscription_id: subscription.external_id,
        timestamp:)

      create(:clickhouse_events_enriched,
        organization_id: organization.id,
        external_subscription_id: subscription.external_id,
        timestamp:)
    end

    context "when PG and CH usage totals diverge and no recent events were received" do
      before do
        stub_usage(1000, 1200)
        stub_stdin(organization.id, "y", "")
      end

      it "aborts" do
        expect { task.invoke }.to raise_error(SystemExit)
        expect(organization.reload.clickhouse_events_store).to be(false)
      end
    end

    context "when PG and CH usage totals diverge but events were received in the last minute" do
      before do
        create(:event,
          organization_id: organization.id,
          subscription:,
          external_subscription_id: subscription.external_id,
          timestamp: 10.seconds.ago)

        allow(Kernel).to receive(:sleep) # rubocop:disable  RSpec/AnyInstance
      end

      context "when the retry resolves the difference" do
        before do
          stub_usage(1000, 1200, 1000, 1000)
          stub_stdin(organization.id, "y", "", "y")
        end

        it "retries and proceeds to enable the store" do
          task.invoke

          expect(organization.reload.clickhouse_events_store).to be(true)
          expect(Invoices::CustomerUsageService).to have_received(:call).exactly(4).times
        end
      end

      context "when the retry still shows a difference" do
        before do
          stub_usage(1000, 1200, 1000, 1300)
          stub_stdin(organization.id, "y", "")
        end

        it "aborts" do
          expect { task.invoke }.to raise_error(SystemExit)
          expect(organization.reload.clickhouse_events_store).to be(false)
        end
      end
    end

    context "when no active subscription matches the top external_ids" do
      let(:subscription) { create(:subscription, :canceled, customer:, organization:) }

      before do
        stub_usage  # never called
        stub_stdin(organization.id, "y", "", "y")
      end

      it "skips the comparison and proceeds" do
        task.invoke

        expect(organization.reload.clickhouse_events_store).to be(true)
        expect(Invoices::CustomerUsageService).not_to have_received(:call)
      end
    end
  end
end
