# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fees::EstimateInstant::BatchPayInAdvanceService do
  subject { described_class.new(organization:, external_subscription_id:, events:) }

  let(:organization) { create(:organization) }
  let(:billable_metric) { create(:sum_billable_metric, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:charge) { create(:percentage_charge, :pay_in_advance, plan:, billable_metric:, properties: {rate: "0.1", fixed_amount: "0"}) }

  let(:customer) { create(:customer, organization:) }

  let(:subscription) do
    create(
      :subscription,
      customer:,
      plan:,
      started_at: 1.year.ago
    )
  end

  let(:event) do
    {
      organization_id:,
      code:,
      transaction_id:,
      external_customer_id:,
      external_subscription_id:,
      timestamp:,
      properties:
    }
  end
  let(:events) { [event] }

  let(:transaction_id) { SecureRandom.uuid }

  let(:properties) { nil }

  let(:code) { billable_metric&.code }
  let(:external_customer_id) { customer&.external_id }
  let(:external_subscription_id) { subscription&.external_id }
  let(:organization_id) { organization.id }
  let(:timestamp) { Time.current.to_i.to_s }
  let(:currency) { subscription.plan.amount.currency }

  before { charge }

  # TODO: these are copied from the non-batch service. does it make sense to creata a shared_example?
  context "with 1 event" do
    describe "#call" do
      it "returns a list of fees" do
        result = subject.call

        expect(result).to be_success
        expect(result.fees.count).to eq(1)

        fee = result.fees.first
        expect(fee).to be_a(Hash)
        expect(fee).to include(
          pay_in_advance: true,
          invoiceable: charge.invoiceable,
          events_count: 1,
          event_transaction_id: transaction_id
        )
      end

      context "when setting event properties" do
        let(:properties) { {billable_metric.field_name => 500} }

        it "calculates the fee correctly" do
          result = subject.call

          expect(result).to be_success
          expect(result.fees.count).to eq(1)

          fee = result.fees.first
          expect(fee[:amount_cents]).to eq(50)
        end
      end

      context "when charge is standard charge" do
        let(:charge) { create(:standard_charge, :pay_in_advance, plan:, billable_metric:, properties: {amount: "10"}) }

        it "returns a list of fees" do
          result = subject.call

          expect(result).to be_success
          expect(result.fees.count).to eq(1)

          fee = result.fees.first
          expect(fee).to be_a(Hash)
          expect(fee).to include(
            pay_in_advance: true,
            invoiceable: charge.invoiceable,
            events_count: 1,
            event_transaction_id: transaction_id
          )
        end

        context "when setting event properties" do
          let(:properties) { {billable_metric.field_name => 500} }

          it "calculates the fee correctly" do
            result = subject.call

            expect(result).to be_success
            expect(result.fees.count).to eq(1)

            fee = result.fees.first
            expect(fee[:amount_cents]).to eq(500000)
          end
        end

        context "when billable metric has an expression configured" do
          let(:billable_metric) { create(:sum_billable_metric, organization:, expression: "event.properties.test * 2") }
          let(:properties) { {"test" => 200} }

          it "calculates evaluates the expression before estimating" do
            result = subject.call

            expect(result).to be_success
            expect(result.fees.count).to eq(1)

            fee = result.fees.first
            expect(fee[:amount_cents]).to eq(400000)
          end
        end
      end

      context "when billable metric has an expression configured" do
        let(:billable_metric) { create(:sum_billable_metric, organization:, expression: "event.properties.test * 2") }
        let(:properties) { {"test" => 200} }

        it "calculates evaluates the expression before estimating" do
          result = subject.call

          expect(result).to be_success
          expect(result.fees.count).to eq(1)

          fee = result.fees.first
          expect(fee[:amount_cents]).to eq(40)
        end
      end

      context "when event code does not match an pay_in_advance charge" do
        let(:charge) { create(:percentage_charge, plan:, billable_metric:) }

        it "fails with a validation error" do
          result = subject.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:code]).to eq(["does_not_match_an_instant_charge"])
        end
      end

      context "when event matches multiple charges" do
        let(:charge2) { create(:standard_charge, :pay_in_advance, plan:, billable_metric:) }

        before { charge2 }

        it "returns a fee per charges" do
          result = subject.call

          expect(result).to be_success
          expect(result.fees.count).to eq(2)
        end
      end

      context "when external subscription is not found" do
        let(:external_subscription_id) { nil }

        it "fails with a not found error" do
          result = subject.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.error_code).to eq("subscription_not_found")
        end
      end

      context "when billable metric does not have field name to run aggregation on" do
        let(:billable_metric) { create(:billable_metric, organization:) }
        let(:charge) { create(:percentage_charge, :pay_in_advance, plan:, billable_metric:, properties: {rate: "10", fixed_amount: "0"}) }
        let(:properties) { {} }

        it "takes the whole event as one unit" do
          result = subject.call

          expect(result).to be_success
          expect(result.fees.count).to eq(1)

          fee = result.fees.first
          expect(fee[:amount_cents]).to eq(10)
          expect(fee[:units]).to eq(1)
        end
      end
    end
  end

  context "with multiple events" do
    let(:billable_metric2) { create(:sum_billable_metric, organization:) }
    let(:charge2) { create(:standard_charge, :pay_in_advance, plan:, billable_metric: billable_metric2, properties: {amount: "1"}) }
    let(:event2) do
      {
        organization_id:,
        code: billable_metric2.code,
        transaction_id: SecureRandom.uuid,
        external_customer_id:,
        external_subscription_id:,
        timestamp:,
        properties: properties2
      }
    end
    let(:properties2) { nil }
    let(:events) { [event, event2] }

    before { charge2 }

    describe "#call" do
      it "returns a list of fees" do
        result = subject.call

        expect(result).to be_success
        expect(result.fees.count).to eq(2)

        fee1 = result.fees.find { |f| f[:event_transaction_id] == event[:transaction_id] }
        fee2 = result.fees.find { |f| f[:event_transaction_id] == event2[:transaction_id] }
        expect(fee1).to be_a(Hash)
        expect(fee1).to include(
          pay_in_advance: true,
          invoiceable: charge.invoiceable,
          events_count: 1,
          event_transaction_id: transaction_id
        )
        expect(fee2).to be_a(Hash)
        expect(fee2).to include(
          pay_in_advance: true,
          invoiceable: charge.invoiceable,
          events_count: 1,
          event_transaction_id: event2[:transaction_id]
        )
      end
    end

    context "when properties are set" do
      let(:properties) { {billable_metric.field_name => 100} }
      let(:properties2) { {billable_metric2.field_name => 500} }

      it "calculates the fee correctly" do
        result = subject.call

        expect(result).to be_success
        expect(result.fees.count).to eq(2)

        fee1 = result.fees.find { |f| f[:event_transaction_id] == event[:transaction_id] }
        fee2 = result.fees.find { |f| f[:event_transaction_id] == event2[:transaction_id] }
        expect(fee1[:amount_cents]).to eq(10)
        expect(fee2[:amount_cents]).to eq(50000)
      end
    end

    context "when external subscription is not found" do
      let(:external_subscription_id) { nil }

      it "fails with a not found error" do
        result = subject.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.error_code).to eq("subscription_not_found")
      end
    end
  end
end
