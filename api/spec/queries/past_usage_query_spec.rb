# frozen_string_literal: true

require "rails_helper"

RSpec.describe PastUsageQuery do
  subject(:result) { described_class.call(organization:, pagination:, filters:) }

  let(:organization) { create(:organization) }
  let(:pagination) { nil }
  let(:filters) do
    {
      external_customer_id: customer.external_id,
      external_subscription_id: subscription.external_id
    }
  end

  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, customer:, plan:) }
  let(:subscription2) { create(:subscription, customer:, plan:) }

  let(:invoice_subscription1) do
    create(
      :invoice_subscription,
      charges_from_datetime: DateTime.parse("2023-08-17T00:00:00"),
      charges_to_datetime: DateTime.parse("2023-09-16T23:59:59"),
      subscription:
    )
  end

  let(:invoice_subscription2) do
    create(
      :invoice_subscription,
      charges_from_datetime: DateTime.parse("2023-07-17T00:00:00"),
      charges_to_datetime: DateTime.parse("2023-08-16T23:59:59"),
      subscription:
    )
  end

  let(:invoice_subscription3) do
    create(
      :invoice_subscription,
      charges_from_datetime: DateTime.parse("2023-07-17T00:00:00"),
      charges_to_datetime: DateTime.parse("2023-08-16T23:59:59"),
      subscription: subscription2
    )
  end

  before do
    invoice_subscription1
    invoice_subscription2
  end

  it "returns a list of invoice_subscription" do
    expect(result).to be_success
    expect(result.usage_periods.count).to eq(2)
  end

  context "when invoice subscriptions have the same values for the ordering criteria" do
    let(:invoice_subscription2) do
      create(
        :invoice_subscription,
        id: "00000000-0000-0000-0000-000000000000",
        charges_from_datetime: invoice_subscription1.charges_from_datetime,
        charges_to_datetime: invoice_subscription1.charges_to_datetime,
        subscription:,
        created_at: invoice_subscription1.created_at
      )
    end

    it "returns a consistent list" do
      result_invoice_subscriptions_ids = result.usage_periods.map(&:invoice_subscription).map(&:id)

      expect(result).to be_success
      expect(result.usage_periods.count).to eq(2)
      expect(result_invoice_subscriptions_ids).to include(invoice_subscription1.id)
      expect(result_invoice_subscriptions_ids).to include(invoice_subscription2.id)
      expect(result_invoice_subscriptions_ids.index(invoice_subscription1.id))
        .to be > result_invoice_subscriptions_ids.index(invoice_subscription2.id)
    end
  end

  context "with pagination" do
    let(:pagination) { {page: 2, limit: 2} }

    before do
      create(
        :invoice_subscription,
        charges_from_datetime: DateTime.parse("2023-06-17T00:00:00"),
        charges_to_datetime: DateTime.parse("2023-07-16T23:59:59"),
        subscription:
      )
    end

    it "applies the pagination" do
      expect(result).to be_success
      expect(result.current_page).to eq(2)
      expect(result.prev_page).to eq(1)
      expect(result.next_page).to be_nil
      expect(result.total_pages).to eq(2)
      expect(result.total_count).to eq(3)
    end
  end

  context "when external_customer_id is missing" do
    let(:filters) { {external_subscription_id: subscription.external_id} }

    it "returns a validation failure" do
      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::ValidationFailure)
      expect(result.error.messages.keys).to include(:external_customer_id)
      expect(result.error.messages[:external_customer_id]).to include("value_is_mandatory")
    end
  end

  context "when external_subscription_id is missing" do
    let(:filters) { {external_customer_id: customer.external_id} }

    it "returns a validation failure" do
      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::ValidationFailure)
      expect(result.error.messages.keys).to include(:external_subscription_id)
      expect(result.error.messages[:external_subscription_id]).to include("value_is_mandatory")
    end
  end

  context "with fees belonging to multiple subscriptions" do
    let(:billable_metric1) { create(:billable_metric, organization:) }
    let(:billable_metric_code) { billable_metric1&.code }

    let(:billable_metric2) { create(:billable_metric, organization:) }

    let(:charge1) { create(:standard_charge, plan:, billable_metric: billable_metric1) }
    let(:charge2) { create(:standard_charge, plan:, billable_metric: billable_metric2) }

    let(:fee1) { create(:charge_fee, charge: charge1, subscription:, invoice: invoice_subscription1.invoice) }
    let(:fee2) { create(:charge_fee, charge: charge2, subscription: subscription2, invoice: invoice_subscription1.invoice) }

    let(:filters) do
      {
        external_customer_id: customer.external_id,
        external_subscription_id: subscription.external_id
      }
    end

    before do
      invoice_subscription3
      fee1
      fee2
    end

    it "filters the fees accordingly" do
      expect(result).to be_success
      expect(result.usage_periods.count).to eq(2)
      expect(result.usage_periods.first.fees.count).to eq(1)
      expect(result.usage_periods.first.fees.first.subscription).to eq(subscription)
    end
  end

  context "with billable_metric_code" do
    let(:billable_metric1) { create(:billable_metric, organization:) }
    let(:billable_metric_code) { billable_metric1&.code }

    let(:billable_metric2) { create(:billable_metric, organization:) }

    let(:charge1) { create(:standard_charge, plan:, billable_metric: billable_metric1) }
    let(:charge2) { create(:standard_charge, plan:, billable_metric: billable_metric2) }

    let(:fee1) { create(:charge_fee, charge: charge1, subscription:, invoice: invoice_subscription1.invoice) }
    let(:fee2) { create(:charge_fee, charge: charge2, subscription:, invoice: invoice_subscription1.invoice) }

    let(:filters) do
      {
        external_customer_id: customer.external_id,
        external_subscription_id: subscription.external_id,
        billable_metric_code:
      }
    end

    before do
      fee1
      fee2
    end

    it "filters the fees accordingly" do
      expect(result).to be_success
      expect(result.usage_periods.count).to eq(2)
      expect(result.usage_periods.first.fees.count).to eq(1)
    end

    context "when billable metric is not found" do
      let(:billable_metric_code) { "unknown_code" }

      it "returns a not found failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.error_code).to eq("billable_metric_not_found")
      end
    end
  end

  context "with periods_count filter" do
    let(:periods_count) { 1 }
    let(:filters) do
      {
        external_customer_id: customer.external_id,
        external_subscription_id: subscription.external_id,
        periods_count:
      }
    end

    it "returns last requested periods" do
      expect(result).to be_success
      expect(result.usage_periods.count).to eq(1)
      expect(result.usage_periods.first.invoice_subscription).to eq(invoice_subscription1)
    end

    context "when periods_count is higher than billed period count" do
      let(:periods_count) { 10 }

      it "returns all periods" do
        expect(result).to be_success
        expect(result.usage_periods.count).to eq(2)
      end
    end
  end
end
