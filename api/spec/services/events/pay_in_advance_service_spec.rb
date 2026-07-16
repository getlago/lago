# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::PayInAdvanceService do
  let(:in_advance_service) { described_class.new(event:) }

  let(:organization) { create(:organization) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:, plan:, started_at:) }
  let(:event_properties) { {} }
  let(:timestamp) { Time.current - 1.second }
  let(:code) { billable_metric&.code }
  let(:external_subscription_id) { subscription.external_id }
  let(:started_at) { Time.current - 3.days }

  let(:event) do
    build(
      :common_event,
      id: SecureRandom.uuid,
      organization_id: organization.id,
      code:,
      external_subscription_id: subscription.external_id,
      properties: event_properties
    )
  end

  describe "#call" do
    let(:charge) { create(:standard_charge, :pay_in_advance, plan:, billable_metric:, invoiceable: false) }
    let(:billable_metric) do
      create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "item_id")
    end

    let(:event_properties) { {billable_metric.field_name => "12"} }

    before { charge }

    it "enqueues a job to perform the pay_in_advance aggregation" do
      expect { in_advance_service.call }.to have_enqueued_job(Fees::CreatePayInAdvanceJob)
    end

    context "when charge is invoiceable" do
      before { charge.update!(invoiceable: true) }

      it "does not enqueue a job to perform the pay_in_advance aggregation" do
        expect { in_advance_service.call }.not_to have_enqueued_job(Fees::CreatePayInAdvanceJob)
      end
    end

    context "when multiple charges have the billable metric" do
      before { create(:standard_charge, :pay_in_advance, plan:, billable_metric:, invoiceable: false) }

      it "enqueues a job for each charge" do
        expect { in_advance_service.call }.to have_enqueued_job(Fees::CreatePayInAdvanceJob).twice
      end
    end

    context "when event matches a pay_in_advance charge that is invoiceable" do
      let(:charge) { create(:standard_charge, :pay_in_advance, plan:, billable_metric:, invoiceable: true) }
      let(:billable_metric) do
        create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "item_id")
      end

      let(:event_properties) { {billable_metric.field_name => "12"} }

      before { charge }

      it "enqueues a job to create the pay_in_advance charge invoice" do
        expect { in_advance_service.call }.to have_enqueued_job(Invoices::CreatePayInAdvanceChargeJob)
      end

      context "when charge is not invoiceable" do
        before { charge.update!(invoiceable: false) }

        it "does not enqueue a job to create the pay_in_advance charge invoice" do
          expect { in_advance_service.call }
            .not_to have_enqueued_job(Invoices::CreatePayInAdvanceChargeJob)
        end
      end

      context "when multiple charges have the billable metric" do
        before { create(:standard_charge, :pay_in_advance, plan:, billable_metric:, invoiceable: true) }

        it "enqueues a job for each charge" do
          expect { in_advance_service.call }
            .to have_enqueued_job(Invoices::CreatePayInAdvanceChargeJob).twice
        end
      end

      context "when value for sum_agg is negative" do
        let(:event_properties) { {billable_metric.field_name => "-5"} }

        it "enqueues a job" do
          expect { in_advance_service.call }
            .to have_enqueued_job(Invoices::CreatePayInAdvanceChargeJob)
        end
      end

      context "when event field name does not batch the BM one" do
        let(:event_properties) { {"wrong_field_name" => "-5"} }

        it "does not enqueue a job" do
          expect { in_advance_service.call }
            .not_to have_enqueued_job(Invoices::CreatePayInAdvanceChargeJob)
        end
      end
    end

    context "when fees exists with the same transaction_id" do
      before do
        create(
          :fee,
          subscription:,
          invoice: nil,
          pay_in_advance_event_transaction_id: event.transaction_id
        )
      end

      it "does not enqueue a job" do
        expect do
          expect { in_advance_service.call }.not_to have_enqueued_job(Fees::CreatePayInAdvanceJob)
        end.not_to have_enqueued_job(Invoices::CreatePayInAdvanceChargeJob)
      end
    end

    context "when event is comming from kafka" do
      before do
        ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"] ||= "kafla:9092"
        ENV["LAGO_KAFKA_RAW_EVENTS_TOPIC"] ||= "raw_events"

        event.id = nil
      end

      it "does not process the event" do
        expect do
          expect { in_advance_service.call }.not_to have_enqueued_job(Fees::CreatePayInAdvanceJob)
        end.not_to have_enqueued_job(Invoices::CreatePayInAdvanceChargeJob)
      end

      context "when organization is using clickhouse" do
        before { organization.update!(clickhouse_events_store: true) }

        it "enqueues a job to perform the pay_in_advance aggregation" do
          expect { in_advance_service.call }.to have_enqueued_job(Fees::CreatePayInAdvanceJob)
        end
      end
    end
  end
end
