# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::Customers::PastUsageSerializer do
  subject(:serializer) { described_class.new(usage, root_name: "usage_period", includes: [:charges_usage]) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, customer:, plan:) }

  let(:invoice_subscription) do
    create(
      :invoice_subscription,
      charges_from_datetime: DateTime.parse("2023-08-17T00:00:00"),
      charges_to_datetime: DateTime.parse("2023-09-16T23:59:59"),
      subscription:
    )
  end

  let(:billable_metric1) { create(:billable_metric, organization:) }
  let(:billable_metric2) { create(:billable_metric, organization:) }

  let(:charge1) { create(:standard_charge, plan:, billable_metric: billable_metric1) }
  let(:charge2) { create(:standard_charge, plan:, billable_metric: billable_metric2) }

  let(:invoice) { invoice_subscription.invoice }

  let(:fee1) { create(:charge_fee, charge: charge1, invoice:, presentation_breakdowns: [build(:presentation_breakdown)]) }
  let(:fee2) { create(:charge_fee, charge: charge2, invoice:) }

  let(:usage) { OpenStruct.new(invoice_subscription:, fees: [fee1, fee2]) }

  it "serializes the past usage" do
    result = JSON.parse(serializer.to_json)

    expect(result["usage_period"]).to include(
      "from_datetime" => "2023-08-17T00:00:00Z",
      "to_datetime" => "2023-09-16T23:59:59Z",
      "issuing_date" => invoice.issuing_date.iso8601,
      "currency" => invoice.currency,
      "amount_cents" => invoice.fees_amount_cents,
      "total_amount_cents" => invoice.fees_amount_cents + invoice.fees.sum(:taxes_amount_cents),
      "taxes_amount_cents" => invoice.fees.sum(:taxes_amount_cents),
      "lago_invoice_id" => invoice.id
    )

    expect(result["usage_period"]["charges_usage"].count).to eq(2)
    expect(result["usage_period"]["charges_usage"].first["presentation_breakdowns"]).to eq([{"presentation_by" => {"department" => "engineering"}, "units" => "60.0"}])
    expect(result["usage_period"]["charges_usage"].second["presentation_breakdowns"]).to eq([])
  end
end
