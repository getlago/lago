# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeFilters::CreateOrUpdateBatchService do
  subject(:service) { described_class.call(charge:, filters_params:) }

  let(:charge) { create(:standard_charge) }
  let(:filters_params) { {} }

  let(:card_location_filter) do
    create(
      :billable_metric_filter,
      billable_metric: charge.billable_metric,
      key: "card_location",
      values: %w[domestic international]
    )
  end

  let(:scheme_filter) do
    create(
      :billable_metric_filter,
      billable_metric: charge.billable_metric,
      key: "scheme",
      values: %w[visa mastercard]
    )
  end

  let(:card_type_filter) do
    create(
      :billable_metric_filter,
      billable_metric: charge.billable_metric,
      key: "card_type",
      values: %w[debit credit]
    )
  end

  context "when filter values hash is empty" do
    let(:filters_params) do
      [
        {
          values: {},
          invoice_display_name: "Invalid filter",
          properties: {amount: "10"}
        }
      ]
    end

    before { card_location_filter }

    it "returns a validation failure" do
      expect(service).not_to be_success
      expect(service.error).to be_a(BaseService::ValidationFailure)
      expect(service.error.messages[:values]).to eq(["value_is_mandatory"])
    end

    it "does not create any filters" do
      expect { service }.not_to change(ChargeFilter, :count)
    end
  end

  context "when only one of multiple filter_params has empty values" do
    let(:filters_params) do
      [
        {
          values: {card_location_filter.key => ["domestic"]},
          invoice_display_name: "Valid filter",
          properties: {amount: "10"}
        },
        {
          values: {},
          invoice_display_name: "Invalid filter",
          properties: {amount: "20"}
        }
      ]
    end

    it "returns a validation failure" do
      expect(service).not_to be_success
      expect(service.error).to be_a(BaseService::ValidationFailure)
      expect(service.error.messages[:values]).to eq(["value_is_mandatory"])
    end

    it "does not create any filters" do
      expect { service }.not_to change(ChargeFilter, :count)
    end
  end

  context "when filter params is empty" do
    it "does not create any filters" do
      expect { service }.not_to change(ChargeFilter, :count)
    end

    context "when there are existing filters" do
      let(:filter) { create(:charge_filter, charge:) }

      let(:filter_value) do
        create(
          :charge_filter_value,
          charge_filter: filter,
          billable_metric_filter: card_location_filter,
          values: [card_location_filter.values.first]
        )
      end

      before { filter_value }

      it "discards all filters and the related values" do
        expect { service }.to change { filter.reload.discarded? }.to(true)
          .and change { filter_value.reload.discarded? }.to(true)
      end
    end
  end

  context "with new filters" do
    let(:filters_params) do
      [
        {
          values: {
            card_location_filter.key => ["domestic"],
            scheme_filter.key => ["visa"]
          },
          invoice_display_name: "Visa domestic card payment",
          properties: {amount: "10"}
        },
        {
          values: {
            card_location_filter.key => ["domestic"],
            scheme_filter.key => ["visa"],
            card_type_filter.key => ["debit"]
          },
          invoice_display_name: "Visa debit domestic card payment",
          properties: {amount: "20", pricing_group_keys: ["region"]}
        }
      ]
    end

    it "creates the filters and their values" do
      expect { service }.to change(ChargeFilter, :count).by(2)

      filter1 = charge.filters.find_by(invoice_display_name: "Visa domestic card payment")
      expect(filter1).to have_attributes(
        invoice_display_name: "Visa domestic card payment",
        properties: {"amount" => "10"}
      )
      expect(filter1.values.count).to eq(2)
      expect(filter1.values.pluck(:values).flatten).to match_array(%w[domestic visa])

      filter2 = charge.filters.find_by(invoice_display_name: "Visa debit domestic card payment")
      expect(filter2).to have_attributes(
        invoice_display_name: "Visa debit domestic card payment",
        properties: {"amount" => "20", "pricing_group_keys" => ["region"]}
      )
      expect(filter2.values.count).to eq(3)
      expect(filter2.values.pluck(:values).flatten).to match_array(%w[domestic visa debit])
    end

    context "when filters properties contain not relevant values" do
      let(:charge) { create(:graduated_charge) }
      let(:filters_params) do
        [
          {
            values: {
              card_location_filter.key => ["domestic"],
              scheme_filter.key => ["visa"]
            },
            invoice_display_name: "Visa domestic card payment",
            properties: {amount: "10", graduated_ranges: [{from_value: 0, to_value: nil, per_unit_amount: "0", flat_amount: "200"}]}
          },
          {
            values: {
              card_location_filter.key => ["domestic"],
              scheme_filter.key => ["visa"],
              card_type_filter.key => ["debit"]
            },
            invoice_display_name: "Visa debit domestic card payment",
            properties: {amount: "20", graduated_ranges: [{from_value: 0, to_value: nil, per_unit_amount: "0", flat_amount: "200"}]}
          }
        ]
      end

      it "removes the not relevant values from the properties" do
        expect { service }.to change(ChargeFilter, :count).by(2)

        filter1 = charge.filters.find_by(invoice_display_name: "Visa domestic card payment")
        expect(filter1.properties).to eq("graduated_ranges" => [
          {"from_value" => 0, "to_value" => nil, "per_unit_amount" => "0", "flat_amount" => "200"}
        ])

        filter2 = charge.filters.find_by(invoice_display_name: "Visa debit domestic card payment")
        expect(filter2.properties).to eq("graduated_ranges" => [
          {"from_value" => 0, "to_value" => nil, "per_unit_amount" => "0", "flat_amount" => "200"}
        ])
      end
    end

    it "returns a successful result with filters ordered as in input params" do
      result = service

      expect(result).to be_success
      expect(result.filters.count).to eq(2)
      expect(result.filters.map(&:invoice_display_name)).to eq(
        ["Visa domestic card payment", "Visa debit domestic card payment"]
      )
    end

    context "when filter properties contain presentation_group_keys" do
      let(:filters_params) do
        [
          {
            values: {card_location_filter.key => ["domestic"], scheme_filter.key => ["visa"]},
            invoice_display_name: "Visa domestic card payment",
            properties: {amount: "10", presentation_group_keys: [{"value" => "region"}]}
          }
        ]
      end

      it "strips presentation_group_keys from the stored properties" do
        expect { service }.to change(ChargeFilter, :count).by(1)

        filter = charge.filters.find_by(invoice_display_name: "Visa domestic card payment")
        expect(filter.properties).to eq("amount" => "10")
      end
    end
  end

  context "with existing filters" do
    let(:filter) { create(:charge_filter, charge:) }
    let(:filter_values) do
      [
        create(
          :charge_filter_value,
          charge_filter: filter,
          billable_metric_filter: card_location_filter,
          values: ["domestic"]
        ),
        create(
          :charge_filter_value,
          charge_filter: filter,
          billable_metric_filter: scheme_filter,
          values: ["visa"]
        )
      ]
    end

    let(:filters_params) do
      [
        {
          values: {
            card_location_filter.key => ["domestic"],
            scheme_filter.key => ["visa"]
          },
          invoice_display_name: "New display name",
          properties: {amount: "20"}.merge(pricing_group_keys)
        }
      ]
    end

    let(:pricing_group_keys) { {pricing_group_keys: ["region"]} }

    before { filter_values }

    it "updates the filter" do
      expect { service }.not_to change(ChargeFilter, :count)
      expect(filter.reload).to have_attributes(
        invoice_display_name: "New display name",
        properties: {"amount" => "20", "pricing_group_keys" => ["region"]}
      )
      expect(filter.values.count).to eq(2)
      expect(filter.values.pluck(:values).flatten).to match_array(%w[domestic visa])
    end

    context "when the existing filter matches the request exactly" do
      let(:filter) do
        create(:charge_filter,
          charge:,
          invoice_display_name: "Same display name",
          properties: {"amount" => "10"},
          updated_at: 1.day.ago)
      end

      let(:filter_values) do
        [
          create(:charge_filter_value,
            charge_filter: filter,
            billable_metric_filter: card_location_filter,
            values: ["domestic"],
            updated_at: 1.day.ago),
          create(:charge_filter_value,
            charge_filter: filter,
            billable_metric_filter: scheme_filter,
            values: ["visa"],
            updated_at: 1.day.ago)
        ]
      end

      let(:filters_params) do
        [
          {
            values: {
              card_location_filter.key => ["domestic"],
              scheme_filter.key => ["visa"]
            },
            invoice_display_name: "Same display name",
            properties: {amount: "10"}
          }
        ]
      end

      it "touches the unchanged filter to preserve input order under updated_at ASC" do
        previous_updated_at = filter.reload.updated_at

        service

        expect(filter.reload.updated_at).to be > previous_updated_at
      end

      it "touches each unchanged filter_value to preserve input order under updated_at ASC" do
        previous_updated_ats = filter_values.map { it.reload.updated_at }

        service

        filter_values.zip(previous_updated_ats).each do |fv, previous_updated_at|
          expect(fv.reload.updated_at).to be > previous_updated_at
        end
      end
    end

    context "when changing filter values" do
      let(:filters_params) do
        [
          {
            values: {
              card_location_filter.key => ["international"],
              scheme_filter.key => ["mastercard"]
            },
            invoice_display_name: "New display name",
            properties: {amount: "20"}
          }
        ]
      end

      it "creates a new filter and removes the existing one" do
        result = service

        expect(result.filters.count).to eq(1)
        expect(filter.reload).to be_discarded

        new_filter = result.filters.first
        expect(new_filter.values.count).to eq(2)
        expect(new_filter.values.pluck(:values).flatten).to match_array(%w[international mastercard])
      end

      it "soft-deletes the values of the removed filter" do
        service

        expect(filter_values.map { it.reload.discarded? }).to all(be true)
      end
    end

    context "when adding a value into filter values" do
      let(:filters_params) do
        [
          {
            values: {
              card_location_filter.key => ["domestic"],
              scheme_filter.key => %w[visa mastercard]
            },
            invoice_display_name: "New display name",
            properties: {amount: "20"}
          }
        ]
      end

      it "creates a new filter and removes the existing one" do
        result = service

        expect(result.filters.count).to eq(1)
        expect(filter.reload).to be_discarded

        new_filter = result.filters.first
        expect(new_filter.values.count).to eq(2)
        expect(new_filter.values.pluck(:values).flatten).to match_array(%w[domestic visa mastercard])
      end
    end
  end

  context "with a mix of kept, new and removed filters" do
    let(:filter_to_keep) { create(:charge_filter, charge:, invoice_display_name: "Old name") }
    let(:filter_to_keep_value) do
      create(
        :charge_filter_value,
        charge_filter: filter_to_keep,
        billable_metric_filter: card_location_filter,
        values: ["domestic"]
      )
    end

    let(:filter_to_remove) { create(:charge_filter, charge:, invoice_display_name: "To remove") }
    let(:filter_to_remove_value) do
      create(
        :charge_filter_value,
        charge_filter: filter_to_remove,
        billable_metric_filter: card_location_filter,
        values: ["international"]
      )
    end

    let(:filters_params) do
      [
        {
          values: {card_location_filter.key => ["domestic"]},
          invoice_display_name: "Updated name",
          properties: {amount: "10"}
        },
        {
          values: {scheme_filter.key => ["visa"]},
          invoice_display_name: "Brand new filter",
          properties: {amount: "20"}
        }
      ]
    end

    before do
      filter_to_keep_value
      filter_to_remove_value
    end

    it "updates matching filters, creates new ones and discards the rest" do
      result = service

      expect(result).to be_success
      expect(result.filters.count).to eq(2)

      expect(filter_to_keep.reload).not_to be_discarded
      expect(filter_to_keep.invoice_display_name).to eq("Updated name")
      expect(filter_to_keep.properties).to eq("amount" => "10")

      expect(filter_to_remove.reload).to be_discarded
      expect(filter_to_remove_value.reload).to be_discarded

      new_filter = result.filters.find { it.invoice_display_name == "Brand new filter" }
      expect(new_filter).not_to be_nil
      expect(new_filter.values.pluck(:values).flatten).to eq(["visa"])
    end
  end
end
