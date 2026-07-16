# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillableMetrics::DestroyService do
  subject(:destroy_service) { described_class.new(metric: billable_metric) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:subscription) { create(:subscription) }
  let(:charge) { create(:standard_charge, plan: subscription.plan, billable_metric:) }

  before do
    charge

    allow(BillableMetrics::DeleteEventsJob).to receive(:perform_later).and_call_original
    allow(Invoices::RefreshDraftService).to receive(:call)
  end

  describe "#call" do
    it "soft deletes the billable metric" do
      freeze_time do
        expect { destroy_service.call }.to change(BillableMetric, :count).by(-1)
          .and change { billable_metric.reload.deleted_at }.from(nil).to(Time.current)
      end
    end

    it "soft deletes all the related charges" do
      freeze_time do
        expect { destroy_service.call }.to change { charge.reload.deleted_at }.from(nil).to(Time.current)
      end
    end

    it "soft deletes all the related alerts" do
      alert = create(:billable_metric_current_usage_amount_alert, billable_metric:, organization:)
      freeze_time do
        expect { destroy_service.call }.to change { alert.reload.deleted_at }.from(nil).to(Time.current)
      end
    end

    it "enqueues a BillableMetricFilters::DestroyAllJob" do
      expect { destroy_service.call }
        .to have_enqueued_job(BillableMetricFilters::DestroyAllJob).with(billable_metric.id)
    end

    it "enqueues a BillableMetrics::DeleteEventsJob" do
      expect do
        destroy_service.call
      end.to have_enqueued_job(BillableMetrics::DeleteEventsJob).with(billable_metric)
    end

    it "enqueues a billable_metric.deleted webhook" do
      destroy_service.call

      expect(SendWebhookJob).to have_been_enqueued.with("billable_metric.deleted", billable_metric)
    end

    it "marks invoice as ready to be refreshed" do
      invoice = create(:invoice, :draft)
      create(:invoice_subscription, subscription:, invoice:)

      expect { destroy_service.call }.to change { invoice.reload.ready_to_be_refreshed }.to(true)
    end

    context "when billable metric is not found" do
      it "returns an error" do
        result = described_class.new(metric: nil).call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("billable_metric_not_found")
      end
    end
  end

  describe ".call" do
    it "produces an activity log" do
      described_class.call(metric: billable_metric)

      expect(Utils::ActivityLog).to have_produced("billable_metric.deleted").after_commit.with(billable_metric)
    end
  end
end
