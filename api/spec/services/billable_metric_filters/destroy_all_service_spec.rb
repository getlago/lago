# frozen_string_literal: true

RSpec.describe BillableMetricFilters::DestroyAllService do
  subject(:destroy_service) { described_class.new(billable_metric) }

  let(:billable_metric) { create(:billable_metric, :deleted) }
  let(:plan) { create(:plan, organization: billable_metric.organization) }
  let(:charge) { create(:standard_charge, plan:, billable_metric:) }
  let(:filters) { create_list(:billable_metric_filter, 2, billable_metric:) }
  let(:charge_filter) { create(:charge_filter, charge:) }
  let(:filter_value) do
    create(:charge_filter_value, charge_filter:, billable_metric_filter: filters.first)
  end

  before { filter_value }

  describe "#call" do
    it "soft deletes all related filters" do
      freeze_time do
        expect { destroy_service.call }.to change { billable_metric.filters.reload.kept.count }.from(2).to(0)
          .and change { filter_value.reload.reload.deleted_at }.from(nil).to(Time.current)
      end
    end

    context "when the billable metric is not deleted" do
      let(:billable_metric) { create(:billable_metric) }

      it "does not delete the filters" do
        expect { destroy_service.call }.not_to change { billable_metric.filters.reload.kept.count }
      end
    end

    context "when the billable metric is nil" do
      let(:billable_metric) { nil }
      let(:filter_value) { nil }

      it "returns an empty result" do
        result = destroy_service.call
        expect(result).to be_success
        expect(result.billable_metric).to be_nil
      end
    end
  end
end
