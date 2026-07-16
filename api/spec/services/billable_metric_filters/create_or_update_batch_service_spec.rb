# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillableMetricFilters::CreateOrUpdateBatchService do
  subject(:service) { described_class.call(billable_metric:, filters_params:) }

  let(:billable_metric) { create(:billable_metric) }

  context "when filter params is empty" do
    let(:filters_params) { {} }

    it "does not create any filters" do
      expect { service }.not_to change(BillableMetricFilter, :count)
    end

    it "does not enqueue the refresh draft invoices job" do
      expect { service }.not_to have_enqueued_job(BillableMetricFilters::RefreshDraftInvoicesJob)
    end

    context "when there are existing filters" do
      let(:filter) { create(:billable_metric_filter, billable_metric:, key: "region") }

      let(:charge) { create(:standard_charge, billable_metric:) }
      let(:charge_filter) { create(:charge_filter, charge:) }
      let(:filter_value) do
        create(
          :charge_filter_value,
          charge_filter:,
          billable_metric_filter: filter,
          values: [filter.values.first]
        )
      end

      before do
        create(:billable_metric_filter, billable_metric:, key: "cloud")
        filter_value
      end

      it "discards all filters and the related values" do
        expect { service }.to change { BillableMetricFilter.with_discarded.discarded.count }.from(0).to(2)
          .and change { ChargeFilterValue.with_discarded.discarded.count }.from(0).to(1)
          .and change { ChargeFilter.with_discarded.discarded.count }.from(0).to(1)
      end

      context "when a charge_filter has filter_values from multiple billable_metric_filters" do
        let(:other_filter) { create(:billable_metric_filter, billable_metric:, key: "cloud") }
        let(:other_filter_value) do
          create(
            :charge_filter_value,
            charge_filter:,
            billable_metric_filter: other_filter,
            values: [other_filter.values.first]
          )
        end

        before { other_filter_value }

        it "discards all filters, all filter_values, and the shared charge_filter" do
          expect { service }.to change { BillableMetricFilter.with_discarded.discarded.count }.from(0).to(3)
            .and change { ChargeFilterValue.with_discarded.discarded.count }.from(0).to(2)
            .and change { ChargeFilter.with_discarded.discarded.count }.from(0).to(1)
        end
      end
    end
  end

  context "with new filters" do
    let(:filters_params) do
      [
        {
          key: "region",
          values: %w[Europe US]
        },
        {
          key: "cloud",
          values: %w[aws gcp]
        }
      ]
    end

    it "enqueues the refresh draft invoices job" do
      expect { service }.to have_enqueued_job_after_commit(BillableMetricFilters::RefreshDraftInvoicesJob)
        .with(billable_metric.id)
    end

    it "creates the filters" do
      expect { service }.to change(BillableMetricFilter, :count).by(2)

      filter1 = billable_metric.filters.find_by(key: "region")
      expect(filter1).to have_attributes(
        key: "region",
        values: %w[Europe US]
      )

      filter2 = billable_metric.filters.find_by(key: "cloud")
      expect(filter2).to have_attributes(
        key: "cloud",
        values: %w[aws gcp]
      )
    end

    context "when filter param has duplicate values" do
      let(:filters_params) do
        [{key: "region", values: %w[US US Europe Europe]}]
      end

      it "stores deduplicated values" do
        service

        expect(billable_metric.filters.find_by(key: "region").values).to eq(%w[US Europe])
      end
    end

    context "when any of multiple filter params has blank values" do
      let(:filters_params) do
        [
          {key: "region", values: %w[US]},
          {key: "cloud", values: []}
        ]
      end

      it "returns a validation failure" do
        result = service

        expect(result).not_to be_success
        expect(result.error.messages[:values]).to eq(["value_is_mandatory"])
      end

      it "does not persist the valid filter" do
        expect { service }.not_to change(BillableMetricFilter, :count)
      end

      it "does not enqueue the refresh draft invoices job" do
        expect { service }.not_to have_enqueued_job(BillableMetricFilters::RefreshDraftInvoicesJob)
      end
    end
  end

  context "with existing filters" do
    let(:filters_params) do
      [
        {
          key: "region",
          values: %w[Europe US Asia Africa]
        }
      ]
    end

    let(:filter) { create(:billable_metric_filter, billable_metric:, key: "region", values: %w[Europe US Asia]) }

    before { filter }

    it "updates the filters" do
      expect { service }.not_to change(BillableMetricFilter, :count)

      expect(filter.reload).to have_attributes(
        key: "region",
        values: %w[Europe US Asia Africa]
      )
    end

    context "when filter_param has the same values as the existing filter" do
      let(:filters_params) do
        [{key: "region", values: %w[Europe US Asia]}]
      end

      it "leaves the filter values unchanged" do
        expect { service }.not_to change(BillableMetricFilter, :count)
        expect(filter.reload.values).to eq(%w[Europe US Asia])
      end
    end

    context "when a value is removed" do
      let(:filters_params) do
        [
          {
            key: "region",
            values: %w[Europe]
          }
        ]
      end

      let!(:filter_value) do
        create(
          :charge_filter_value,
          billable_metric_filter: filter,
          values: ["US"]
        )
      end

      it "discards the removed value" do
        expect { service }.not_to change(BillableMetricFilter, :count)

        expect(filter.reload).to have_attributes(
          key: "region",
          values: %w[Europe]
        )

        expect(filter_value.reload).to be_discarded
      end

      context "when a filter_value has both kept and removed values" do
        let!(:partial_filter_value) do
          create(
            :charge_filter_value,
            billable_metric_filter: filter,
            values: %w[US Europe]
          )
        end

        it "trims the partial filter_value and discards the fully-removed one in the same batch" do
          service

          expect(partial_filter_value.reload).not_to be_discarded
          expect(partial_filter_value.values).to eq(%w[Europe])

          expect(filter_value.reload).to be_discarded
        end
      end

      context "when the discarded filter_value's charge_filter has a kept filter_value from another filter" do
        let(:other_filter) { create(:billable_metric_filter, billable_metric:, key: "cloud", values: %w[aws gcp]) }
        let(:charge) { create(:standard_charge, billable_metric:) }
        let(:shared_charge_filter) { create(:charge_filter, charge:) }

        let!(:shared_cfv_region) do
          create(
            :charge_filter_value,
            charge_filter: shared_charge_filter,
            billable_metric_filter: filter,
            values: %w[US]
          )
        end

        let!(:shared_cfv_cloud) do
          create(
            :charge_filter_value,
            charge_filter: shared_charge_filter,
            billable_metric_filter: other_filter,
            values: %w[aws]
          )
        end

        let(:filters_params) do
          [
            {key: "region", values: %w[Europe]},
            {key: "cloud", values: %w[aws gcp]}
          ]
        end

        it "discards the filter_value but keeps the shared charge_filter" do
          service

          expect(shared_cfv_region.reload).to be_discarded
          expect(shared_cfv_cloud.reload).not_to be_discarded
          expect(shared_charge_filter.reload).not_to be_discarded
        end
      end

      context "when removing all values" do
        let(:filters_params) do
          []
        end

        let(:charge) { create(:standard_charge, billable_metric:) }
        let(:charge_filter) { create(:charge_filter, charge:) }

        before do
          create(
            :charge_filter_value,
            charge_filter:,
            billable_metric_filter: filter,
            values: ["US"]
          )

          create(
            :charge_filter_value,
            charge_filter:,
            billable_metric_filter: filter,
            values: ["Europe"]
          )
        end

        it "discards the removed value" do
          expect { service }.to change(BillableMetricFilter, :count).by(-1)

          expect(filter.reload).to be_discarded
          expect(filter.filter_values.with_discarded).to all(be_discarded)
        end
      end
    end

    context "when a filter is removed" do
      let(:filters_params) do
        [
          {
            key: "country",
            values: %w[USA France Germany]
          }
        ]
      end

      it "discards the removed filter" do
        expect { service }.not_to change(BillableMetricFilter, :count)

        expect(filter.reload).to be_discarded
      end

      context "when the removed filter has filter_values and a charge_filter" do
        let(:charge) { create(:standard_charge, billable_metric:) }
        let(:charge_filter) { create(:charge_filter, charge:) }
        let!(:filter_value) do
          create(
            :charge_filter_value,
            charge_filter:,
            billable_metric_filter: filter,
            values: ["US"]
          )
        end

        it "discards the filter, its filter_values, and the emptied charge_filter" do
          service

          expect(filter.reload).to be_discarded
          expect(filter_value.reload).to be_discarded
          expect(charge_filter.reload).to be_discarded
        end
      end
    end

    context "with new, existing, and removed filters together" do
      let(:filters_params) do
        [
          {key: "region", values: %w[Europe US Asia Africa]},
          {key: "cloud", values: %w[aws gcp]}
        ]
      end

      let!(:filter_to_remove) do
        create(:billable_metric_filter, billable_metric:, key: "country", values: %w[Australia])
      end

      it "creates new, updates existing, and discards missing filters" do
        service

        expect(filter.reload).to have_attributes(values: %w[Europe US Asia Africa])
        expect(filter_to_remove.reload).to be_discarded
        expect(billable_metric.filters.find_by(key: "cloud")).to have_attributes(values: %w[aws gcp])
      end
    end
  end

  context "with unrelated records present" do
    let(:other_billable_metric) { create(:billable_metric) }
    let!(:other_filter) { create(:billable_metric_filter, billable_metric: other_billable_metric, key: "region") }
    let(:other_charge) { create(:standard_charge, billable_metric: other_billable_metric) }
    let!(:other_charge_filter) { create(:charge_filter, charge: other_charge) }
    let!(:other_filter_value) do
      create(
        :charge_filter_value,
        charge_filter: other_charge_filter,
        billable_metric_filter: other_filter,
        values: [other_filter.values.first]
      )
    end

    context "when discarding all filters of the billable_metric" do
      let(:filters_params) { {} }

      let(:filter) { create(:billable_metric_filter, billable_metric:) }
      let(:charge) { create(:standard_charge, billable_metric:) }
      let(:charge_filter) { create(:charge_filter, charge:) }
      let(:filter_value) do
        create(:charge_filter_value, charge_filter:, billable_metric_filter: filter, values: [filter.values.first])
      end

      before { filter_value }

      it "discards exactly one of each: filter, filter_value, charge_filter" do
        expect { service }.to change(BillableMetricFilter.kept, :count).by(-1)
          .and change(ChargeFilterValue.kept, :count).by(-1)
          .and change(ChargeFilter.kept, :count).by(-1)
      end

      it "leaves the other billable_metric's filter, filter_value and charge_filter untouched" do
        service

        expect(other_filter.reload).not_to be_discarded
        expect(other_filter_value.reload).not_to be_discarded
        expect(other_charge_filter.reload).not_to be_discarded
      end
    end

    context "when removing values from one filter" do
      let(:filter) { create(:billable_metric_filter, billable_metric:, key: "region", values: %w[US Europe]) }
      let(:filters_params) { [{key: "region", values: %w[Europe]}] }

      let(:cfv_to_discard) do
        create(:charge_filter_value, billable_metric_filter: filter, values: %w[US])
      end

      let!(:cfv_unaffected) do
        create(:charge_filter_value, billable_metric_filter: filter, values: %w[Europe])
      end

      let(:unrelated_charge) { create(:standard_charge, billable_metric:) }
      let!(:unrelated_charge_filter) { create(:charge_filter, charge: unrelated_charge) }

      let!(:already_discarded_cfv) do
        create(:charge_filter_value, billable_metric_filter: filter, values: %w[US]).tap(&:discard!)
      end

      before do
        filter
        cfv_to_discard
      end

      it "discards only the filter_value whose values are being removed" do
        expect { service }.to change(ChargeFilterValue.kept, :count).by(-1)
      end

      it "preserves filter_values whose values aren't being removed" do
        service

        expect(cfv_unaffected.reload).not_to be_discarded
        expect(cfv_unaffected.values).to eq(%w[Europe])
      end

      it "does not touch charge_filters of unrelated charges in the same billable_metric" do
        expect { service }.not_to change { unrelated_charge_filter.reload.discarded? }
      end

      it "does not modify deleted_at on already-discarded filter_values" do
        original_deleted_at = already_discarded_cfv.deleted_at
        service
        expect(already_discarded_cfv.reload.deleted_at).to eq(original_deleted_at)
      end

      it "does not discard pre-existing emptied charge_filters unrelated to this run" do
        expect { service }.not_to change { already_discarded_cfv.charge_filter.reload.discarded? }
      end

      it "leaves the other billable_metric's records untouched" do
        service

        expect(other_filter.reload).not_to be_discarded
        expect(other_filter_value.reload).not_to be_discarded
        expect(other_charge_filter.reload).not_to be_discarded
      end
    end
  end
end
