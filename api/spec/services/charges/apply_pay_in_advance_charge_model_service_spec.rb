# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charges::ApplyPayInAdvanceChargeModelService do
  let(:charge_service) { described_class.new(charge:, aggregation_result:, properties:) }

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:charge) { create(:standard_charge, :pay_in_advance, plan:) }
  let(:subscription) { create(:subscription, plan:) }

  let(:aggregation_result) do
    BillableMetrics::Aggregations::BaseService::Result.new.tap do |result|
      result.aggregation = 10
      result.pay_in_advance_aggregation = 1
      result.count = 5
      result.options = {}
      result.aggregator = aggregator
      result.pay_in_advance_event = pay_in_advance_event
    end
  end
  let(:properties) { {} }

  let(:aggregator) do
    BillableMetrics::Aggregations::CountService.new(
      event_store_class: Events::Stores::PostgresStore,
      charge:,
      subscription: nil,
      boundaries: nil
    )
  end

  let(:pay_in_advance_event) do
    source = create(
      :event,
      external_subscription_id: subscription.external_id,
      external_customer_id: subscription.external_id,
      organization_id: organization.id,
      properties: {}
    )
    Events::CommonFactory.new_instance(source:)
  end

  describe "#call" do
    context "when charge is not pay_in_advance" do
      let(:charge) { create(:standard_charge) }

      it "returns an error" do
        result = charge_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("apply_charge_model_error")
        expect(result.error.error_message).to eq("Charge is not pay_in_advance")
      end
    end

    shared_examples "a charge model" do
      it "delegates to the charge model service" do
        previous_agg_result = BillableMetrics::Aggregations::BaseService::Result.new.tap do |result|
          result.aggregation = 9
          result.count = 4
          result.options = {}
          result.aggregator = aggregator
          result.pay_in_advance_event = pay_in_advance_event
        end

        allow(charge_model_class).to receive(:apply)
          .with(charge:, aggregation_result:, properties:)
          .and_return(BaseService::Result.new.tap { |r| r.amount = 10 })

        allow(charge_model_class).to receive(:apply)
          .with(charge:, aggregation_result: previous_agg_result, properties: properties.merge(exclude_event: true))
          .and_return(BaseService::Result.new.tap { |r| r.amount = 8 })

        result = charge_service.call

        expect(result.units).to eq(1)
        expect(result.count).to eq(1)
        expect(result.amount).to eq(200) # In cents
        expect(result.precise_amount).to eq(200.0) # In cents
        expect(result.unit_amount).to eq(2)
      end

      context "when the event is not persisted" do
        before { pay_in_advance_event.persisted = false }

        it "delegates to the charge model service" do
          non_persisted_agg_result = BillableMetrics::Aggregations::BaseService::Result.new.tap do |result|
            result.aggregation = 11
            result.count = 6
            result.options = {}
            result.aggregator = aggregator
            result.pay_in_advance_event = pay_in_advance_event
          end

          allow(charge_model_class).to receive(:apply)
            .with(charge:, aggregation_result:, properties:)
            .and_return(BaseService::Result.new.tap { |r| r.amount = 8 })

          allow(charge_model_class).to receive(:apply)
            .with(charge:, aggregation_result: non_persisted_agg_result, properties: properties.merge(include_event_value: true))
            .and_return(BaseService::Result.new.tap { |r| r.amount = 10 })

          result = charge_service.call

          expect(result.units).to eq(1)
          expect(result.count).to eq(1)
          expect(result.amount).to eq(2_00) # In cents
          expect(result.precise_amount).to eq(2_00.0) # In cents
          expect(result.unit_amount).to eq(2)
          expect(result.amount_details).to be_nil
        end
      end
    end

    describe "when standard charge model" do
      let(:charge_model_class) { ChargeModels::StandardService }

      it_behaves_like "a charge model"
    end

    describe "when graduated charge model" do
      let(:charge) do
        create(
          :graduated_charge,
          :pay_in_advance,
          plan:,
          properties: {
            graduated_ranges: [
              {
                from_value: 0,
                to_value: nil,
                per_unit_amount: "0.01",
                flat_amount: "0.01"
              }
            ]
          }
        )
      end
      let(:charge_model_class) { ChargeModels::GraduatedService }

      it_behaves_like "a charge model"
    end

    describe "when package charge model" do
      let(:charge) { create(:package_charge, :pay_in_advance, plan:) }
      let(:charge_model_class) { ChargeModels::PackageService }

      it_behaves_like "a charge model"
    end

    describe "when percentage charge model" do
      let(:charge) { create(:percentage_charge, :pay_in_advance, plan:) }
      let(:charge_model_class) { ChargeModels::PercentageService }

      it_behaves_like "a charge model"
    end

    describe "when graduated percentage charge model", :premium do
      let(:charge) do
        create(
          :graduated_percentage_charge,
          :pay_in_advance,
          plan:,
          properties: {
            graduated_percentage_ranges: [
              {
                from_value: 0,
                to_value: nil,
                flat_amount: "0.01",
                rate: "2"
              }
            ]
          }
        )
      end

      let(:charge_model_class) { ChargeModels::GraduatedPercentageService }

      it_behaves_like "a charge model"
    end

    describe "when dynamic charge model" do
      let(:charge) { create(:dynamic_charge, :pay_in_advance, plan:) }
      let(:charge_model_class) { ChargeModels::DynamicService }
      let(:subscription) { create(:subscription, organization:, plan:) }

      let(:aggregator) do
        BillableMetrics::Aggregations::SumService.new(
          event_store_class: Events::Stores::PostgresStore,
          charge:,
          subscription:,
          boundaries: nil
        )
      end

      it_behaves_like "a charge model"
    end
  end
end
