# frozen_string_literal: true

require "rails_helper"

RSpec.describe DailyUsages::ComputeDiffService do
  subject(:diff_service) { described_class.new(daily_usage:, previous_daily_usage:) }

  let(:daily_usage) { create(:daily_usage, usage:) }
  let(:previous_daily_usage) { create(:daily_usage, usage: previous_usage) }

  let(:usage) do
    {
      "from_datetime" => "2022-07-01T00:00:00Z",
      "to_datetime" => "2022-07-31T23:59:59Z",
      "issuing_date" => "2022-08-02",
      "lago_invoice_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
      "currency" => "EUR",
      "amount_cents" => 123,
      "taxes_amount_cents" => 20,
      "total_amount_cents" => 143,
      "charges_usage" => [
        {
          "units" => "1.5",
          "events_count" => 11,
          "amount_cents" => 123,
          "amount_currency" => "EUR",
          "charge" => {
            "lago_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
            "charge_model" => "graduated",
            "invoice_display_name" => "Setup"
          },
          "billable_metric" => {
            "lago_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
            "name" => "Storage",
            "code" => "storage",
            "aggregation_type" => "sum_agg"
          },
          "filters" => [
            {
              "units" => "1.4",
              "amount_cents" => 122,
              "events_count" => 10,
              "invoice_display_name" => "AWS eu-east-1",
              "values" => {
                "region" => "us-east-1"
              }
            },
            {
              "units" => "0.1",
              "amount_cents" => 1,
              "events_count" => 1,
              "invoice_display_name" => "AWS eu-east-2",
              "values" => {
                "region" => "us-east-2"
              }
            }
          ],
          "grouped_usage" => [
            {
              "amount_cents" => 101,
              "events_count" => 6,
              "units" => "1.1",
              "grouped_by" => {"country" => nil},
              "filters" => [
                {
                  "units" => "1.0",
                  "amount_cents" => 100,
                  "events_count" => 5,
                  "invoice_display_name" => "AWS eu-east-1",
                  "values" => {
                    "region" => "us-east-1"
                  }
                },
                {
                  "units" => "0.1",
                  "amount_cents" => 1,
                  "events_count" => 1,
                  "invoice_display_name" => "AWS eu-east-2",
                  "values" => {
                    "region" => "us-east-2"
                  }
                }
              ]
            },
            {
              "amount_cents" => 22,
              "events_count" => 5,
              "units" => "0.4",
              "grouped_by" => {"country" => "us"},
              "filters" => [
                {
                  "units" => "0.4",
                  "amount_cents" => 22,
                  "events_count" => 5,
                  "invoice_display_name" => "AWS eu-east-1",
                  "values" => {
                    "region" => "us-east-1"
                  }
                }
              ]
            }
          ]
        }
      ]
    }
  end

  let(:previous_usage) do
    {
      "from_datetime" => "2022-07-01T00:00:00Z",
      "to_datetime" => "2022-07-31T23:59:59Z",
      "issuing_date" => "2022-08-01",
      "lago_invoice_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
      "currency" => "EUR",
      "amount_cents" => 100,
      "taxes_amount_cents" => 15,
      "total_amount_cents" => 115,
      "charges_usage" => [
        {
          "units" => "1.0",
          "events_count" => 5,
          "amount_cents" => 100,
          "amount_currency" => "EUR",
          "charge" => {
            "lago_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
            "charge_model" => "graduated",
            "invoice_display_name" => "Setup"
          },
          "billable_metric" => {
            "lago_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
            "name" => "Storage",
            "code" => "storage",
            "aggregation_type" => "sum_agg"
          },
          "filters" => [
            {
              "units" => "1.0",
              "amount_cents" => 100,
              "events_count" => 5,
              "invoice_display_name" => "AWS eu-east-1",
              "values" => {
                "region" => "us-east-1"
              }
            }
          ],
          "grouped_usage" => [
            {
              "amount_cents" => 100,
              "events_count" => 5,
              "units" => "1.0",
              "grouped_by" => {"country" => nil},
              "filters" => [
                {
                  "units" => "1.0",
                  "amount_cents" => 100,
                  "events_count" => 5,
                  "invoice_display_name" => "AWS eu-east-1",
                  "values" => {
                    "region" => "us-east-1"
                  }
                }
              ]
            }
          ]
        }
      ]
    }
  end

  it "computes the diff between the two daily usages" do
    result = diff_service.call

    expect(result).to be_success
    expect(result.usage_diff).to eq(
      {
        "from_datetime" => "2022-07-01T00:00:00Z",
        "to_datetime" => "2022-07-31T23:59:59Z",
        "issuing_date" => "2022-08-02",
        "lago_invoice_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
        "currency" => "EUR",
        "amount_cents" => 23,
        "taxes_amount_cents" => 5,
        "total_amount_cents" => 28,
        "charges_usage" => [
          {
            "units" => "0.5",
            "events_count" => 6,
            "amount_cents" => 23,
            "amount_currency" => "EUR",
            "charge" => {
              "lago_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
              "charge_model" => "graduated",
              "invoice_display_name" => "Setup"
            },
            "billable_metric" => {
              "lago_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
              "name" => "Storage",
              "code" => "storage",
              "aggregation_type" => "sum_agg"
            },
            "filters" => [
              {
                "units" => "0.4",
                "amount_cents" => 22,
                "events_count" => 5,
                "invoice_display_name" => "AWS eu-east-1",
                "values" => {
                  "region" => "us-east-1"
                }
              },
              {
                "units" => "0.1",
                "amount_cents" => 1,
                "events_count" => 1,
                "invoice_display_name" => "AWS eu-east-2",
                "values" => {
                  "region" => "us-east-2"
                }
              }
            ],
            "grouped_usage" => [
              {
                "amount_cents" => 1,
                "events_count" => 1,
                "units" => "0.1",
                "grouped_by" => {"country" => nil},
                "filters" => [
                  {
                    "units" => "0.0",
                    "amount_cents" => 0,
                    "events_count" => 0,
                    "invoice_display_name" => "AWS eu-east-1",
                    "values" => {
                      "region" => "us-east-1"
                    }
                  },
                  {
                    "units" => "0.1",
                    "amount_cents" => 1,
                    "events_count" => 1,
                    "invoice_display_name" => "AWS eu-east-2",
                    "values" => {
                      "region" => "us-east-2"
                    }
                  }
                ]
              },
              {
                "amount_cents" => 22,
                "events_count" => 5,
                "units" => "0.4",
                "grouped_by" => {"country" => "us"},
                "filters" => [
                  {
                    "units" => "0.4",
                    "amount_cents" => 22,
                    "events_count" => 5,
                    "invoice_display_name" => "AWS eu-east-1",
                    "values" => {
                      "region" => "us-east-1"
                    }
                  }
                ]
              }
            ]
          }
        ]
      }
    )
  end

  context "when a charge is deleted between snapshots" do
    let(:charge_a_id) { "aaaa1111-1a90-1a90-1a90-1a901a901a90" }
    let(:charge_c_id) { "cccc3333-1a90-1a90-1a90-1a901a901a90" }

    let(:usage) do
      {
        "from_datetime" => "2022-07-01T00:00:00Z",
        "to_datetime" => "2022-07-31T23:59:59Z",
        "issuing_date" => "2022-08-02",
        "lago_invoice_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
        "currency" => "EUR",
        "amount_cents" => 150,
        "taxes_amount_cents" => 15,
        "total_amount_cents" => 165,
        "charges_usage" => [
          {
            "units" => "1.5",
            "events_count" => 8,
            "amount_cents" => 150,
            "amount_currency" => "EUR",
            "charge" => {"lago_id" => charge_a_id, "charge_model" => "standard", "invoice_display_name" => "API Calls"},
            "billable_metric" => {"lago_id" => "bm-a", "name" => "API Calls", "code" => "api_calls", "aggregation_type" => "sum_agg"},
            "filters" => [],
            "grouped_usage" => []
          }
        ]
      }
    end

    let(:previous_usage) do
      {
        "from_datetime" => "2022-07-01T00:00:00Z",
        "to_datetime" => "2022-07-31T23:59:59Z",
        "issuing_date" => "2022-08-01",
        "lago_invoice_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
        "currency" => "EUR",
        "amount_cents" => 300,
        "taxes_amount_cents" => 30,
        "total_amount_cents" => 330,
        "charges_usage" => [
          {
            "units" => "1.0",
            "events_count" => 5,
            "amount_cents" => 100,
            "amount_currency" => "EUR",
            "charge" => {"lago_id" => charge_a_id, "charge_model" => "standard", "invoice_display_name" => "API Calls"},
            "billable_metric" => {"lago_id" => "bm-a", "name" => "API Calls", "code" => "api_calls", "aggregation_type" => "sum_agg"},
            "filters" => [],
            "grouped_usage" => []
          },
          {
            "units" => "2.0",
            "events_count" => 10,
            "amount_cents" => 200,
            "amount_currency" => "EUR",
            "charge" => {"lago_id" => charge_c_id, "charge_model" => "standard", "invoice_display_name" => "Storage"},
            "billable_metric" => {"lago_id" => "bm-c", "name" => "Storage", "code" => "storage", "aggregation_type" => "sum_agg"},
            "filters" => [],
            "grouped_usage" => []
          }
        ]
      }
    end

    it "derives top-level amounts from per-charge diffs, ignoring the deleted charge" do
      result = diff_service.call

      expect(result).to be_success

      diff = result.usage_diff

      expect(diff["amount_cents"]).to eq(50)
      expect(diff["taxes_amount_cents"]).to eq(5)
      expect(diff["total_amount_cents"]).to eq(55)

      expect(diff["charges_usage"].size).to eq(1)
      charge_a_diff = diff["charges_usage"].first
      expect(charge_a_diff["charge"]["lago_id"]).to eq(charge_a_id)
      expect(charge_a_diff["amount_cents"]).to eq(50)
      expect(charge_a_diff["units"]).to eq("0.5")
      expect(charge_a_diff["events_count"]).to eq(3)
    end
  end

  context "when a new charge is added between snapshots" do
    let(:charge_a_id) { "aaaa1111-1a90-1a90-1a90-1a901a901a90" }
    let(:charge_b_id) { "bbbb2222-1a90-1a90-1a90-1a901a901a90" }

    let(:usage) do
      {
        "from_datetime" => "2022-07-01T00:00:00Z",
        "to_datetime" => "2022-07-31T23:59:59Z",
        "issuing_date" => "2022-08-02",
        "lago_invoice_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
        "currency" => "EUR",
        "amount_cents" => 200,
        "taxes_amount_cents" => 20,
        "total_amount_cents" => 220,
        "charges_usage" => [
          {
            "units" => "1.5",
            "events_count" => 8,
            "amount_cents" => 150,
            "amount_currency" => "EUR",
            "charge" => {"lago_id" => charge_a_id, "charge_model" => "standard", "invoice_display_name" => "API Calls"},
            "billable_metric" => {"lago_id" => "bm-a", "name" => "API Calls", "code" => "api_calls", "aggregation_type" => "sum_agg"},
            "filters" => [],
            "grouped_usage" => []
          },
          {
            "units" => "0.5",
            "events_count" => 3,
            "amount_cents" => 50,
            "amount_currency" => "EUR",
            "charge" => {"lago_id" => charge_b_id, "charge_model" => "standard", "invoice_display_name" => "Storage"},
            "billable_metric" => {"lago_id" => "bm-b", "name" => "Storage", "code" => "storage", "aggregation_type" => "sum_agg"},
            "filters" => [],
            "grouped_usage" => []
          }
        ]
      }
    end

    let(:previous_usage) do
      {
        "from_datetime" => "2022-07-01T00:00:00Z",
        "to_datetime" => "2022-07-31T23:59:59Z",
        "issuing_date" => "2022-08-01",
        "lago_invoice_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
        "currency" => "EUR",
        "amount_cents" => 100,
        "taxes_amount_cents" => 10,
        "total_amount_cents" => 110,
        "charges_usage" => [
          {
            "units" => "1.0",
            "events_count" => 5,
            "amount_cents" => 100,
            "amount_currency" => "EUR",
            "charge" => {"lago_id" => charge_a_id, "charge_model" => "standard", "invoice_display_name" => "API Calls"},
            "billable_metric" => {"lago_id" => "bm-a", "name" => "API Calls", "code" => "api_calls", "aggregation_type" => "sum_agg"},
            "filters" => [],
            "grouped_usage" => []
          }
        ]
      }
    end

    it "includes the new charge's full amount in the diff" do
      result = diff_service.call

      expect(result).to be_success

      diff = result.usage_diff

      expect(diff["amount_cents"]).to eq(100)
      expect(diff["taxes_amount_cents"]).to eq(10)
      expect(diff["total_amount_cents"]).to eq(110)

      expect(diff["charges_usage"].size).to eq(2)

      charge_a_diff = diff["charges_usage"].find { |cu| cu["charge"]["lago_id"] == charge_a_id }
      expect(charge_a_diff["amount_cents"]).to eq(50)
      expect(charge_a_diff["units"]).to eq("0.5")
      expect(charge_a_diff["events_count"]).to eq(3)

      charge_b_diff = diff["charges_usage"].find { |cu| cu["charge"]["lago_id"] == charge_b_id }
      expect(charge_b_diff["amount_cents"]).to eq(50)
      expect(charge_b_diff["units"]).to eq("0.5")
      expect(charge_b_diff["events_count"]).to eq(3)
    end
  end

  context "when all charges are replaced between snapshots" do
    let(:charge_a_id) { "aaaa1111-1a90-1a90-1a90-1a901a901a90" }
    let(:charge_b_id) { "bbbb2222-1a90-1a90-1a90-1a901a901a90" }

    let(:usage) do
      {
        "from_datetime" => "2022-07-01T00:00:00Z",
        "to_datetime" => "2022-07-31T23:59:59Z",
        "issuing_date" => "2022-08-02",
        "lago_invoice_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
        "currency" => "EUR",
        "amount_cents" => 80,
        "taxes_amount_cents" => 8,
        "total_amount_cents" => 88,
        "charges_usage" => [
          {
            "units" => "2.0",
            "events_count" => 4,
            "amount_cents" => 80,
            "amount_currency" => "EUR",
            "charge" => {"lago_id" => charge_b_id, "charge_model" => "standard", "invoice_display_name" => "Storage"},
            "billable_metric" => {"lago_id" => "bm-b", "name" => "Storage", "code" => "storage", "aggregation_type" => "sum_agg"},
            "filters" => [],
            "grouped_usage" => []
          }
        ]
      }
    end

    let(:previous_usage) do
      {
        "from_datetime" => "2022-07-01T00:00:00Z",
        "to_datetime" => "2022-07-31T23:59:59Z",
        "issuing_date" => "2022-08-01",
        "lago_invoice_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
        "currency" => "EUR",
        "amount_cents" => 100,
        "taxes_amount_cents" => 10,
        "total_amount_cents" => 110,
        "charges_usage" => [
          {
            "units" => "1.0",
            "events_count" => 5,
            "amount_cents" => 100,
            "amount_currency" => "EUR",
            "charge" => {"lago_id" => charge_a_id, "charge_model" => "standard", "invoice_display_name" => "API Calls"},
            "billable_metric" => {"lago_id" => "bm-a", "name" => "API Calls", "code" => "api_calls", "aggregation_type" => "sum_agg"},
            "filters" => [],
            "grouped_usage" => []
          }
        ]
      }
    end

    it "does not deduct any previous taxes since no charges overlap" do
      result = diff_service.call

      diff = result.usage_diff

      expect(diff["amount_cents"]).to eq(80)
      expect(diff["taxes_amount_cents"]).to eq(8)
      expect(diff["total_amount_cents"]).to eq(88)

      charge_b_diff = diff["charges_usage"].first
      expect(charge_b_diff["charge"]["lago_id"]).to eq(charge_b_id)
      expect(charge_b_diff["amount_cents"]).to eq(80)
    end
  end

  context "when previous amount_cents is zero" do
    let(:charge_a_id) { "aaaa1111-1a90-1a90-1a90-1a901a901a90" }

    let(:usage) do
      {
        "from_datetime" => "2022-07-01T00:00:00Z",
        "to_datetime" => "2022-07-31T23:59:59Z",
        "issuing_date" => "2022-08-02",
        "lago_invoice_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
        "currency" => "EUR",
        "amount_cents" => 50,
        "taxes_amount_cents" => 5,
        "total_amount_cents" => 55,
        "charges_usage" => [
          {
            "units" => "1.0",
            "events_count" => 3,
            "amount_cents" => 50,
            "amount_currency" => "EUR",
            "charge" => {"lago_id" => charge_a_id, "charge_model" => "standard", "invoice_display_name" => "API Calls"},
            "billable_metric" => {"lago_id" => "bm-a", "name" => "API Calls", "code" => "api_calls", "aggregation_type" => "sum_agg"},
            "filters" => [],
            "grouped_usage" => []
          }
        ]
      }
    end

    let(:previous_usage) do
      {
        "from_datetime" => "2022-07-01T00:00:00Z",
        "to_datetime" => "2022-07-31T23:59:59Z",
        "issuing_date" => "2022-08-01",
        "lago_invoice_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
        "currency" => "EUR",
        "amount_cents" => 0,
        "taxes_amount_cents" => 0,
        "total_amount_cents" => 0,
        "charges_usage" => [
          {
            "units" => "0.0",
            "events_count" => 0,
            "amount_cents" => 0,
            "amount_currency" => "EUR",
            "charge" => {"lago_id" => charge_a_id, "charge_model" => "standard", "invoice_display_name" => "API Calls"},
            "billable_metric" => {"lago_id" => "bm-a", "name" => "API Calls", "code" => "api_calls", "aggregation_type" => "sum_agg"},
            "filters" => [],
            "grouped_usage" => []
          }
        ]
      }
    end

    it "skips ratio calculation and deducts full previous taxes" do
      result = diff_service.call

      diff = result.usage_diff

      expect(diff["amount_cents"]).to eq(50)
      expect(diff["taxes_amount_cents"]).to eq(5)
      expect(diff["total_amount_cents"]).to eq(55)
    end
  end

  context "when charges are both added and deleted between snapshots" do
    let(:charge_a_id) { "aaaa1111-1a90-1a90-1a90-1a901a901a90" }
    let(:charge_b_id) { "bbbb2222-1a90-1a90-1a90-1a901a901a90" }
    let(:charge_c_id) { "cccc3333-1a90-1a90-1a90-1a901a901a90" }

    let(:usage) do
      {
        "from_datetime" => "2022-07-01T00:00:00Z",
        "to_datetime" => "2022-07-31T23:59:59Z",
        "issuing_date" => "2022-08-02",
        "lago_invoice_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
        "currency" => "EUR",
        "amount_cents" => 250,
        "taxes_amount_cents" => 25,
        "total_amount_cents" => 275,
        "charges_usage" => [
          {
            "units" => "2.0",
            "events_count" => 8,
            "amount_cents" => 200,
            "amount_currency" => "EUR",
            "charge" => {"lago_id" => charge_a_id, "charge_model" => "standard", "invoice_display_name" => "API Calls"},
            "billable_metric" => {"lago_id" => "bm-a", "name" => "API Calls", "code" => "api_calls", "aggregation_type" => "sum_agg"},
            "filters" => [],
            "grouped_usage" => []
          },
          {
            "units" => "1.0",
            "events_count" => 2,
            "amount_cents" => 50,
            "amount_currency" => "EUR",
            "charge" => {"lago_id" => charge_c_id, "charge_model" => "standard", "invoice_display_name" => "Bandwidth"},
            "billable_metric" => {"lago_id" => "bm-c", "name" => "Bandwidth", "code" => "bandwidth", "aggregation_type" => "sum_agg"},
            "filters" => [],
            "grouped_usage" => []
          }
        ]
      }
    end

    let(:previous_usage) do
      {
        "from_datetime" => "2022-07-01T00:00:00Z",
        "to_datetime" => "2022-07-31T23:59:59Z",
        "issuing_date" => "2022-08-01",
        "lago_invoice_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
        "currency" => "EUR",
        "amount_cents" => 300,
        "taxes_amount_cents" => 30,
        "total_amount_cents" => 330,
        "charges_usage" => [
          {
            "units" => "1.0",
            "events_count" => 5,
            "amount_cents" => 100,
            "amount_currency" => "EUR",
            "charge" => {"lago_id" => charge_a_id, "charge_model" => "standard", "invoice_display_name" => "API Calls"},
            "billable_metric" => {"lago_id" => "bm-a", "name" => "API Calls", "code" => "api_calls", "aggregation_type" => "sum_agg"},
            "filters" => [],
            "grouped_usage" => []
          },
          {
            "units" => "3.0",
            "events_count" => 10,
            "amount_cents" => 200,
            "amount_currency" => "EUR",
            "charge" => {"lago_id" => charge_b_id, "charge_model" => "standard", "invoice_display_name" => "Storage"},
            "billable_metric" => {"lago_id" => "bm-b", "name" => "Storage", "code" => "storage", "aggregation_type" => "sum_agg"},
            "filters" => [],
            "grouped_usage" => []
          }
        ]
      }
    end

    it "prorates taxes based on overlapping charge ratio and includes new charge fully" do
      # Previous: A(100) + B(200) = 300, taxes = 30
      # Current:  A(200) + C(50)  = 250, taxes = 25
      # Only charge A overlaps: 100/300 = 1/3 of previous taxes = 10
      # Diff amount: A(200-100) + C(50) = 150
      # Diff taxes: 25 - 10 = 15
      result = diff_service.call

      diff = result.usage_diff

      expect(diff["amount_cents"]).to eq(150)
      expect(diff["taxes_amount_cents"]).to eq(15)
      expect(diff["total_amount_cents"]).to eq(165)

      expect(diff["charges_usage"].size).to eq(2)

      charge_a_diff = diff["charges_usage"].find { |cu| cu["charge"]["lago_id"] == charge_a_id }
      expect(charge_a_diff["amount_cents"]).to eq(100)
      expect(charge_a_diff["units"]).to eq("1.0")
      expect(charge_a_diff["events_count"]).to eq(3)

      charge_c_diff = diff["charges_usage"].find { |cu| cu["charge"]["lago_id"] == charge_c_id }
      expect(charge_c_diff["amount_cents"]).to eq(50)
      expect(charge_c_diff["units"]).to eq("1.0")
      expect(charge_c_diff["events_count"]).to eq(2)
    end
  end

  context "when previous_daily_usage is not provided" do
    subject(:diff_service) { described_class.new(daily_usage:) }

    let(:subscription) { create(:subscription) }
    let(:from_datetime) { Time.zone.parse("2022-07-01T00:00:00Z") }
    let(:to_datetime) { Time.zone.parse("2022-07-31T23:59:59Z") }

    let(:daily_usage) do
      create(:daily_usage, subscription:, from_datetime:, to_datetime:, usage_date: Date.new(2022, 7, 15), usage:)
    end

    let(:usage) do
      {
        "from_datetime" => "2022-07-01T00:00:00Z",
        "to_datetime" => "2022-07-31T23:59:59Z",
        "issuing_date" => "2022-08-02",
        "lago_invoice_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
        "currency" => "EUR",
        "amount_cents" => 150,
        "taxes_amount_cents" => 0,
        "total_amount_cents" => 150,
        "charges_usage" => [
          {
            "units" => "1.5",
            "events_count" => 8,
            "amount_cents" => 150,
            "amount_currency" => "EUR",
            "charge" => {"lago_id" => "aaaa1111-1a90-1a90-1a90-1a901a901a90", "charge_model" => "standard", "invoice_display_name" => "API Calls"},
            "billable_metric" => {"lago_id" => "bm-a", "name" => "API Calls", "code" => "api_calls", "aggregation_type" => "sum_agg"},
            "filters" => [],
            "grouped_usage" => []
          }
        ]
      }
    end

    let(:previous_usage_data) do
      {
        "from_datetime" => "2022-07-01T00:00:00Z",
        "to_datetime" => "2022-07-31T23:59:59Z",
        "issuing_date" => "2022-08-01",
        "lago_invoice_id" => "1a901a90-1a90-1a90-1a90-1a901a901a90",
        "currency" => "EUR",
        "amount_cents" => 100,
        "taxes_amount_cents" => 0,
        "total_amount_cents" => 100,
        "charges_usage" => [
          {
            "units" => "1.0",
            "events_count" => 5,
            "amount_cents" => 100,
            "amount_currency" => "EUR",
            "charge" => {"lago_id" => "aaaa1111-1a90-1a90-1a90-1a901a901a90", "charge_model" => "standard", "invoice_display_name" => "API Calls"},
            "billable_metric" => {"lago_id" => "bm-a", "name" => "API Calls", "code" => "api_calls", "aggregation_type" => "sum_agg"},
            "filters" => [],
            "grouped_usage" => []
          }
        ]
      }
    end

    before do
      create(
        :daily_usage,
        subscription:,
        from_datetime:,
        to_datetime:,
        usage_date: Date.new(2022, 7, 14),
        usage: previous_usage_data
      )
    end

    it "automatically finds the previous daily usage from the database" do
      result = diff_service.call

      diff = result.usage_diff

      expect(diff["amount_cents"]).to eq(50)
      expect(diff["charges_usage"].first["amount_cents"]).to eq(50)
      expect(diff["charges_usage"].first["units"]).to eq("0.5")
      expect(diff["charges_usage"].first["events_count"]).to eq(3)
    end

    context "when there is a gap of several days without events" do
      # Simulates: events on day 4, none on days 5-8, events again on day 9 of the same billing
      # period. The previous daily_usage lives 5 days back, not at usage_date - 1.day, so the
      # diff must look further back than yesterday to avoid double-counting the day 4 events.
      let(:daily_usage) do
        create(:daily_usage, subscription:, from_datetime:, to_datetime:, usage_date: Date.new(2022, 7, 9), usage:)
      end

      before do
        # Wipe the default previous_daily_usage at 2022-07-14 created above; here we only want
        # the 2022-07-04 row to exist as the prior snapshot.
        DailyUsage.where(subscription:).where.not(usage_date: Date.new(2022, 7, 4)).delete_all

        create(
          :daily_usage,
          subscription:,
          from_datetime:,
          to_datetime:,
          usage_date: Date.new(2022, 7, 4),
          usage: previous_usage_data
        )
      end

      it "diffs against the latest prior daily usage in the same billing period" do
        diff = diff_service.call.usage_diff

        expect(diff["amount_cents"]).to eq(50)
        expect(diff["charges_usage"].first["amount_cents"]).to eq(50)
        expect(diff["charges_usage"].first["units"]).to eq("0.5")
        expect(diff["charges_usage"].first["events_count"]).to eq(3)
      end
    end

    context "when a prior daily usage exists in a different billing period" do
      # The prior daily_usage belongs to the previous billing period (different from_datetime /
      # to_datetime); it must NOT be used as the diff baseline for the current period's first
      # row — that row should fall back to "full usage".
      let(:daily_usage) do
        create(:daily_usage, subscription:, from_datetime:, to_datetime:, usage_date: Date.new(2022, 7, 1), usage:)
      end

      before do
        DailyUsage.where(subscription:).where.not(id: daily_usage.id).delete_all

        create(
          :daily_usage,
          subscription:,
          from_datetime: from_datetime - 1.month,
          to_datetime: to_datetime - 1.month,
          usage_date: Date.new(2022, 6, 30),
          usage: previous_usage_data
        )
      end

      it "returns the full current usage instead of diffing across periods" do
        expect(diff_service.call.usage_diff).to eq(usage)
      end
    end
  end

  context "when the previous daily usage is nil" do
    let(:previous_daily_usage) { nil }

    it "returns the current usage as diff" do
      result = diff_service.call

      expect(result).to be_success
      expect(result.usage_diff).to eq(usage)
    end
  end

  describe "presentation_breakdowns" do
    def charge_usage(lago_id:, presentation_breakdowns: [], filters: [], grouped_usage: [])
      {
        "charge" => {"lago_id" => lago_id},
        "units" => "0.0",
        "events_count" => 0,
        "amount_cents" => 0,
        "filters" => filters,
        "grouped_usage" => grouped_usage,
        "presentation_breakdowns" => presentation_breakdowns
      }
    end

    def grouped_usage(grouped_by:, presentation_breakdowns:, filters: [])
      {
        "grouped_by" => grouped_by,
        "units" => "0.0",
        "events_count" => 0,
        "amount_cents" => 0,
        "filters" => filters,
        "presentation_breakdowns" => presentation_breakdowns
      }
    end

    def filter_usage(values:, presentation_breakdowns: [])
      {
        "values" => values,
        "units" => "0.0",
        "events_count" => 0,
        "amount_cents" => 0,
        "invoice_display_name" => nil,
        "presentation_breakdowns" => presentation_breakdowns
      }
    end

    def usage_payload(charges_usage:)
      {
        "amount_cents" => 0,
        "taxes_amount_cents" => 0,
        "charges_usage" => charges_usage
      }
    end

    context "when a presentation breakdown exists in both snapshots" do
      let(:usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-a",
              presentation_breakdowns: [
                {"presentation_by" => {"region" => "us"}, "units" => "1.1"},
                {"presentation_by" => {"region" => "eu"}, "units" => "0.4"}
              ]
            )
          ]
        )
      end

      let(:previous_usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-a",
              presentation_breakdowns: [
                {"presentation_by" => {"region" => "us"}, "units" => "1.0"}
              ]
            )
          ]
        )
      end

      it "diffs non-grouped usage presentation_breakdowns by presentation_by" do
        result = diff_service.call

        expect(result).to be_success

        diff_charge = result.usage_diff.fetch("charges_usage").first
        expect(diff_charge.fetch("presentation_breakdowns")).to eq(
          [
            {"presentation_by" => {"region" => "us"}, "units" => "0.1"},
            {"presentation_by" => {"region" => "eu"}, "units" => "0.4"}
          ]
        )
      end
    end

    context "when presentation breakdowns are nested under grouped_usage" do
      let(:usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-a",
              grouped_usage: [
                grouped_usage(
                  grouped_by: {"country" => nil},
                  presentation_breakdowns: [
                    {"presentation_by" => {"region" => "us-east-1"}, "units" => "1.0"},
                    {"presentation_by" => {"region" => "us-east-2"}, "units" => "0.1"}
                  ]
                ),
                grouped_usage(
                  grouped_by: {"country" => "us"},
                  presentation_breakdowns: [
                    {"presentation_by" => {"region" => "us-east-1"}, "units" => "0.4"}
                  ]
                )
              ]
            )
          ]
        )
      end

      let(:previous_usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-a",
              grouped_usage: [
                grouped_usage(
                  grouped_by: {"country" => nil},
                  presentation_breakdowns: [
                    {"presentation_by" => {"region" => "us-east-1"}, "units" => "1.0"}
                  ]
                )
              ]
            )
          ]
        )
      end

      it "diffs grouped_usage presentation_breakdowns by presentation_by" do
        result = diff_service.call
        expect(result).to be_success

        charge_diff = result.usage_diff.fetch("charges_usage").first
        grouped_nil = charge_diff.fetch("grouped_usage").find { |gu| gu["grouped_by"] == {"country" => nil} }

        expect(grouped_nil.fetch("presentation_breakdowns")).to eq(
          [
            {"presentation_by" => {"region" => "us-east-1"}, "units" => "0.0"},
            {"presentation_by" => {"region" => "us-east-2"}, "units" => "0.1"}
          ]
        )

        grouped_us = charge_diff.fetch("grouped_usage").find { |gu| gu["grouped_by"] == {"country" => "us"} }
        expect(grouped_us.fetch("presentation_breakdowns")).to eq(
          [
            {"presentation_by" => {"region" => "us-east-1"}, "units" => "0.4"}
          ]
        )
      end
    end

    context "when a charge is deleted between snapshots" do
      let(:usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-a",
              presentation_breakdowns: [
                {"presentation_by" => {"region" => "us"}, "units" => "1.5"},
                {"presentation_by" => {"region" => "eu"}, "units" => "0.2"}
              ]
            )
          ]
        )
      end

      let(:previous_usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-a",
              presentation_breakdowns: [
                {"presentation_by" => {"region" => "us"}, "units" => "1.0"}
              ]
            ),
            charge_usage(
              lago_id: "charge-c",
              presentation_breakdowns: [
                {"presentation_by" => {"region" => "us"}, "units" => "2.0"}
              ]
            )
          ]
        )
      end

      it "diffs presentation_breakdowns only for the overlapping charge" do
        diff = diff_service.call.usage_diff
        charge_a = diff.fetch("charges_usage").first

        expect(charge_a.fetch("presentation_breakdowns")).to eq(
          [
            {"presentation_by" => {"region" => "us"}, "units" => "0.5"},
            {"presentation_by" => {"region" => "eu"}, "units" => "0.2"}
          ]
        )
      end
    end

    context "when a new charge is added between snapshots" do
      let(:usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-a",
              presentation_breakdowns: [
                {"presentation_by" => {"region" => "us"}, "units" => "1.5"}
              ]
            ),
            charge_usage(
              lago_id: "charge-b",
              presentation_breakdowns: [
                {"presentation_by" => {"region" => "eu"}, "units" => "0.5"}
              ]
            )
          ]
        )
      end

      let(:previous_usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-a",
              presentation_breakdowns: [
                {"presentation_by" => {"region" => "us"}, "units" => "1.0"}
              ]
            )
          ]
        )
      end

      it "keeps the new charge presentation_breakdowns unchanged" do
        diff = diff_service.call.usage_diff

        charge_a = diff.fetch("charges_usage").find { |cu| cu.dig("charge", "lago_id") == "charge-a" }
        expect(charge_a.fetch("presentation_breakdowns")).to eq(
          [{"presentation_by" => {"region" => "us"}, "units" => "0.5"}]
        )

        charge_b = diff.fetch("charges_usage").find { |cu| cu.dig("charge", "lago_id") == "charge-b" }
        expect(charge_b.fetch("presentation_breakdowns")).to eq(
          [{"presentation_by" => {"region" => "eu"}, "units" => "0.5"}]
        )
      end
    end

    context "when all charges are replaced between snapshots" do
      let(:usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-b",
              presentation_breakdowns: [
                {"presentation_by" => {"region" => "us"}, "units" => "2.0"}
              ]
            )
          ]
        )
      end

      let(:previous_usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-a",
              presentation_breakdowns: [
                {"presentation_by" => {"region" => "us"}, "units" => "1.0"}
              ]
            )
          ]
        )
      end

      it "does not diff presentation_breakdowns when there is no overlap" do
        diff = diff_service.call.usage_diff
        charge_b = diff.fetch("charges_usage").first

        expect(charge_b.fetch("presentation_breakdowns")).to eq(
          [{"presentation_by" => {"region" => "us"}, "units" => "2.0"}]
        )
      end
    end

    context "when charges are both added and deleted between snapshots" do
      let(:usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-a",
              presentation_breakdowns: [
                {"presentation_by" => {"region" => "us"}, "units" => "2.0"}
              ]
            ),
            charge_usage(
              lago_id: "charge-c",
              presentation_breakdowns: [
                {"presentation_by" => {"region" => "eu"}, "units" => "1.0"}
              ]
            )
          ]
        )
      end

      let(:previous_usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-a",
              presentation_breakdowns: [
                {"presentation_by" => {"region" => "us"}, "units" => "1.0"}
              ]
            ),
            charge_usage(
              lago_id: "charge-b",
              presentation_breakdowns: [
                {"presentation_by" => {"region" => "us"}, "units" => "3.0"}
              ]
            )
          ]
        )
      end

      it "diffs presentation_breakdowns for the common charge and keeps new ones" do
        diff = diff_service.call.usage_diff

        charge_a = diff.fetch("charges_usage").find { |cu| cu.dig("charge", "lago_id") == "charge-a" }
        expect(charge_a.fetch("presentation_breakdowns")).to eq(
          [{"presentation_by" => {"region" => "us"}, "units" => "1.0"}]
        )

        charge_c = diff.fetch("charges_usage").find { |cu| cu.dig("charge", "lago_id") == "charge-c" }
        expect(charge_c.fetch("presentation_breakdowns")).to eq(
          [{"presentation_by" => {"region" => "eu"}, "units" => "1.0"}]
        )
      end
    end

    context "when filters in charges_usage contain presentation_breakdowns" do
      let(:usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-a",
              filters: [
                filter_usage(
                  values: {"region" => "us"},
                  presentation_breakdowns: [
                    {"presentation_by" => {"provider" => "aws"}, "units" => "1.1"},
                    {"presentation_by" => {"provider" => "gcp"}, "units" => "0.4"}
                  ]
                )
              ]
            )
          ]
        )
      end

      let(:previous_usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-a",
              filters: [
                filter_usage(
                  values: {"region" => "us"},
                  presentation_breakdowns: [
                    {"presentation_by" => {"provider" => "aws"}, "units" => "1.0"}
                  ]
                )
              ]
            )
          ]
        )
      end

      it "diffs filter presentation_breakdowns by presentation_by" do
        result = diff_service.call
        expect(result).to be_success

        diff_filter = result.usage_diff.fetch("charges_usage").first.fetch("filters").first
        expect(diff_filter.fetch("presentation_breakdowns")).to eq(
          [
            {"presentation_by" => {"provider" => "aws"}, "units" => "0.1"},
            {"presentation_by" => {"provider" => "gcp"}, "units" => "0.4"}
          ]
        )
      end
    end

    context "when filters in grouped_usage contain presentation_breakdowns" do
      let(:usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-a",
              grouped_usage: [
                grouped_usage(
                  grouped_by: {"country" => "us"},
                  filters: [
                    filter_usage(
                      values: {"region" => "east"},
                      presentation_breakdowns: [
                        {"presentation_by" => {"provider" => "aws"}, "units" => "0.5"},
                        {"presentation_by" => {"provider" => "gcp"}, "units" => "0.2"}
                      ]
                    )
                  ],
                  presentation_breakdowns: []
                )
              ]
            )
          ]
        )
      end

      let(:previous_usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-a",
              grouped_usage: [
                grouped_usage(
                  grouped_by: {"country" => "us"},
                  filters: [
                    filter_usage(
                      values: {"region" => "east"},
                      presentation_breakdowns: [
                        {"presentation_by" => {"provider" => "aws"}, "units" => "0.3"}
                      ]
                    )
                  ],
                  presentation_breakdowns: []
                )
              ]
            )
          ]
        )
      end

      it "diffs grouped_usage filter presentation_breakdowns by presentation_by" do
        result = diff_service.call
        expect(result).to be_success

        grouped = result.usage_diff.fetch("charges_usage").first.fetch("grouped_usage").first
        diff_filter = grouped.fetch("filters").first
        expect(diff_filter.fetch("presentation_breakdowns")).to eq(
          [
            {"presentation_by" => {"provider" => "aws"}, "units" => "0.2"},
            {"presentation_by" => {"provider" => "gcp"}, "units" => "0.2"}
          ]
        )
      end
    end

    context "when previous_daily_usage is nil" do
      let(:previous_daily_usage) { nil }

      let(:usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-a",
              presentation_breakdowns: [
                {"presentation_by" => {"region" => "us"}, "units" => "1.5"}
              ]
            )
          ]
        )
      end

      let(:previous_usage) { nil }

      it "returns the current usage as diff (including presentation_breakdowns)" do
        expect(diff_service.call.usage_diff).to eq(usage)
      end
    end

    context "when previous_daily_usage is not provided" do
      subject(:diff_service) { described_class.new(daily_usage:) }

      let(:subscription) { create(:subscription) }
      let(:from_datetime) { Time.zone.parse("2022-07-01T00:00:00Z") }
      let(:to_datetime) { Time.zone.parse("2022-07-31T23:59:59Z") }

      let(:daily_usage) do
        build(
          :daily_usage,
          subscription:,
          from_datetime:,
          to_datetime:,
          usage_date: Date.new(2022, 7, 15),
          usage:
        )
      end

      let(:usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-a",
              presentation_breakdowns: [
                {"presentation_by" => {"region" => "us"}, "units" => "1.5"}
              ]
            )
          ]
        )
      end

      let(:previous_usage) do
        usage_payload(
          charges_usage: [
            charge_usage(
              lago_id: "charge-a",
              presentation_breakdowns: [
                {"presentation_by" => {"region" => "us"}, "units" => "1.0"}
              ]
            )
          ]
        )
      end

      before do
        create(
          :daily_usage,
          subscription:,
          from_datetime:,
          to_datetime:,
          usage_date: Date.new(2022, 7, 14),
          usage: previous_usage
        )
      end

      it "automatically finds the previous usage and diffs presentation_breakdowns" do
        diff = diff_service.call.usage_diff
        expect(diff.fetch("charges_usage").first.fetch("presentation_breakdowns")).to eq(
          [{"presentation_by" => {"region" => "us"}, "units" => "0.5"}]
        )
      end
    end
  end
end
