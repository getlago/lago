# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Create and edit plans with charge filters" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:billable_metric) { create(:sum_billable_metric, organization:, field_name: "value") }

  let(:steps_bm_filter) do
    create(:billable_metric_filter, billable_metric:, key: "steps", values: %w[0-25 26-50 51-100])
  end
  let(:image_size_bm_filter) do
    create(:billable_metric_filter, billable_metric:, key: "image_size", values: %w[1024x1024 512x152])
  end
  let(:model_name_bm_filter) do
    create(:billable_metric_filter, billable_metric:, key: "model_name", values: %w[llama-1 llama-2 llama-3])
  end

  before do
    steps_bm_filter
    image_size_bm_filter
    model_name_bm_filter
  end

  it "allows the creation and update of plans with charge filters" do
    # Create a plan with a charge and filters
    travel_to(Time.zone.parse("2024-03-27T12:00:00")) do
      create_plan(
        {name: "Filtered Plan",
         code: "filtered_plan",
         interval: "monthly",
         amount_cents: 10_000,
         amount_currency: "EUR",
         pay_in_advance: false,
         charges: [
           {
             billable_metric_id: billable_metric.id,
             charge_model: "standard",
             properties: {amount: "0"},
             filters: [
               {
                 invoice_display_name: "f1",
                 properties: {amount: "10"},
                 values: {image_size: ["512x152"], steps: ["0-25"], model_name: ["llama-2"]}
               },
               {
                 invoice_display_name: "f2",
                 properties: {amount: "5"},
                 values: {image_size: ["512x152"], steps: ["0-25"]}
               },
               {
                 invoice_display_name: "f3",
                 properties: {amount: "5"},
                 values: {
                   image_size: [ChargeFilterValue::ALL_FILTER_VALUES],
                   steps: [ChargeFilterValue::ALL_FILTER_VALUES]
                 }
               },
               {
                 invoice_display_name: "f4",
                 properties: {amount: "2.5"},
                 values: {
                   image_size: [ChargeFilterValue::ALL_FILTER_VALUES]
                 }
               }
             ]
           }
         ]}
      )
    end

    plan = organization.plans.find_by(code: "filtered_plan")
    expect(plan.charges.count).to eq(1)

    charge = plan.charges.first
    expect(charge.filters.count).to eq(4)

    # Update the typo on the charge filter values
    travel_to(Time.zone.parse("2024-03-27T14:00:00")) do
      update_metric(
        billable_metric,
        {filters: [
          {key: "image_size", values: %w[1024x1024 512x512]},
          {key: "steps", values: %w[0-25 26-50 51-100]},
          {key: "model_name", values: %w[llama-1 llama-2 llama-3]}
        ]}
      )
    end

    charge.reload
    f1 = charge.filters.find_by(invoice_display_name: "f1")
    expect(f1.to_h.keys).to match_array(%w[steps model_name])

    f2 = charge.filters.find_by(invoice_display_name: "f2")
    expect(f2.to_h.keys).to eq(%w[steps])

    f3 = charge.filters.find_by(invoice_display_name: "f3")
    expect(f3.to_h.keys).to match_array(%w[image_size steps])

    f4 = charge.filters.find_by(invoice_display_name: "f4")
    expect(f4.to_h.keys).to eq(%w[image_size])

    # Update the plan to fix the filters
    travel_to(Time.zone.parse("2024-03-27T16:00:00")) do
      update_plan(
        plan,
        {name: "Filtered Plan",
         code: "filtered_plan",
         interval: "monthly",
         amount_cents: 10_000,
         amount_currency: "EUR",
         pay_in_advance: false,
         charges: [
           {
             billable_metric_id: billable_metric.id,
             id: charge.id,
             charge_model: "standard",
             properties: {amount: "0"},
             filters: [
               {
                 invoice_display_name: "f2",
                 properties: {amount: "5"},
                 values: {image_size: ["512x512"], steps: ["0-25"]}
               },
               {
                 invoice_display_name: "f3",
                 properties: {amount: "5"},
                 values: {
                   image_size: [ChargeFilterValue::ALL_FILTER_VALUES],
                   steps: [ChargeFilterValue::ALL_FILTER_VALUES]
                 }
               },
               {
                 invoice_display_name: "f4",
                 properties: {amount: "2.5"},
                 values: {
                   image_size: [ChargeFilterValue::ALL_FILTER_VALUES]
                 }
               },
               {
                 invoice_display_name: "f1",
                 properties: {amount: "10"},
                 values: {image_size: ["512x512"], steps: ["0-25"], model_name: ["llama-2"]}
               },
               {
                 invoice_display_name: "f5",
                 properties: {amount: "1"},
                 values: {image_size: ["1024x1024"]}
               }
             ]
           }
         ]}
      )

      plan.reload
      charge = plan.charges.first
      expect(charge.filters.count).to eq(5)
    end

    # TODO: send events to check the filters are working
    travel_to(Time.zone.parse("2024-03-28T12:00:00")) do
      create_subscription(
        {external_customer_id: customer.external_id,
         external_id: customer.external_id,
         plan_code: plan.code,
         billing_time: "anniversary"}
      )
    end

    subscription = organization.subscriptions.find_by(external_id: customer.external_id)
    expect(subscription).to be_present

    travel_to(Time.zone.parse("2024-03-29T12:00:00")) do
      # Send an event with more values than the filters
      create_event(
        {code: billable_metric.code,
         transaction_id: SecureRandom.uuid,
         external_subscription_id: customer.external_id,
         properties: {
           value: 10,
           image_size: "512x512",
           steps: "0-25",
           model: "llama-3"
         }}
      )

      create_event(
        {code: billable_metric.code,
         transaction_id: SecureRandom.uuid,
         external_subscription_id: customer.external_id,
         properties: {
           value: 10,
           image: "512x512",
           step: "0-25",
           model: "llama-3"
         }}
      )

      fetch_current_usage(customer:)
      expect(json[:customer_usage][:total_amount_cents]).to eq(5000)
      expect(json[:customer_usage][:charges_usage].count).to eq(1)

      charges_usage = json[:customer_usage][:charges_usage].first
      expect(charges_usage[:filters].count).to eq(6)

      f2_filter = charges_usage[:filters].find { it[:invoice_display_name] == "f2" }
      expect(f2_filter[:amount_cents]).to eq(5000)
      expect(f2_filter[:units]).to eq("10.0")
      expect(f2_filter[:events_count]).to eq(1)
      expect(f2_filter[:invoice_display_name]).to eq("f2")

      charges_usage[:filters].reject { [nil, "f2"].include?(it[:invoice_display_name]) }.each do |filter|
        expect(filter[:amount_cents]).to eq(0)
        expect(filter[:units]).to eq("0.0")
        expect(filter[:events_count]).to eq(0)
      end

      default_filter = charges_usage[:filters].find { it[:invoice_display_name].nil? }
      expect(default_filter[:amount_cents]).to eq(0)
      expect(default_filter[:units]).to eq("10.0")
      expect(default_filter[:events_count]).to eq(1)
    end
  end
end
