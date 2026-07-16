# frozen_string_literal: true

require "rails_helper"

describe "Recurring Fees Subscription Downgrade" do
  let(:organization) { create(:organization, webhook_url: "http://fees.test/wh") }
  let(:customer) { create(:customer, organization:) }
  let(:billable_metric) { create(:unique_count_billable_metric, :recurring, organization:, code: "seats") }
  let(:plan) { create(:plan, organization:, name: "Premium plus", amount_cents: 99.99, pay_in_advance: true) }
  let(:external_subscription_id) { SecureRandom.uuid }
  let(:charge) do
    create(:charge, {
      plan:,
      billable_metric:,
      invoiceable:,
      pay_in_advance:,
      prorated: true,
      properties: {amount: "30", grouped_by:}
    })
  end

  def send_event!(item_id)
    create_event(
      {
        code: billable_metric.code,
        transaction_id: "tr_#{SecureRandom.hex(16)}",
        external_subscription_id:,
        properties: {"item_id" => item_id}
      }
    )
  end

  before do
    charge
    WebMock.stub_request(:post, "http://fees.test/wh").to_return(status: 200, body: "", headers: {})
  end

  describe "when downgrading subscription" do
    let(:invoiceable) { false }
    let(:pay_in_advance) { true }
    let(:grouped_by) { ["item_id"] }
    let(:plan_2) { create(:plan, organization:, name: "downgraded", amount_cents: 49.99, pay_in_advance: true) }

    before do
      create(:charge, {
        plan: plan_2,
        billable_metric:,
        invoiceable:,
        pay_in_advance:,
        prorated: true,
        properties: {amount: "60", grouped_by:}
      })
    end

    context "when all subscriptions are calendar" do
      let(:billing_time) { "calendar" }

      it "performs subscription downgrade and billing correctly" do
        travel_to(DateTime.new(2024, 6, 1, 0, 0)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: external_subscription_id,
              plan_code: plan.code,
              billing_time:
            }
          )
          perform_billing
        end

        travel_to(DateTime.new(2024, 6, 5, 0, 0)) do
          send_event! "user_1"
        end

        travel_to(DateTime.new(2024, 6, 15, 10, 5, 59)) do
          send_event! "user_2"
        end

        travel_to(DateTime.new(2024, 6, 15, 10, 6)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: external_subscription_id,
              plan_code: plan_2.code,
              billing_time:
            }
          )

          expect(customer.subscriptions.order(created_at: :asc).first).to be_active
          expect(customer.invoices.count).to eq(1)
          new_subscription = customer.subscriptions.order(created_at: :asc).last
          expect(new_subscription.plan.code).to eq(plan_2.code)
          expect(new_subscription).to be_pending
          expect(Fee.where(invoice_id: nil, created_at: ...Time.current).count).to eq 2
          expect(Fee.where(invoice_id: nil, created_at: Time.current..).count).to eq 0
        end

        travel_to(DateTime.new(2024, 6, 19, 0, 0)) do
          send_event! "user_3"
          send_event! "user_4"
        end

        travel_to(DateTime.new(2024, 7, 1, 0, 10)) do
          perform_billing
          expect(customer.subscriptions.order(created_at: :asc).first).to be_terminated
          new_subscription = customer.subscriptions.order(created_at: :asc).last
          expect(new_subscription.plan.code).to eq(plan_2.code)
          expect(new_subscription).to be_active
          expect(Fee.where(invoice_id: nil, created_at: Time.current.beginning_of_month..).count).to eq 4
        end
      end
    end

    context "when all subscriptions are anniversary" do
      let(:billing_time) { "anniversary" }

      it "performs subscription downgrade and billing correctly" do
        travel_to(DateTime.new(2024, 6, 4, 0, 0)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: external_subscription_id,
              plan_code: plan.code,
              billing_time:
            }
          )
          perform_billing
        end

        travel_to(DateTime.new(2024, 6, 5, 0, 0)) do
          send_event! "user_1"
        end

        travel_to(DateTime.new(2024, 6, 15, 10, 5, 59)) do
          send_event! "user_2"
        end

        travel_to(DateTime.new(2024, 6, 15, 10, 6)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: external_subscription_id,
              plan_code: plan_2.code,
              billing_time:
            }
          )

          expect(customer.subscriptions.order(created_at: :asc).first).to be_active
          expect(customer.invoices.count).to eq(1)
          new_subscription = customer.subscriptions.order(created_at: :asc).last
          expect(new_subscription.plan.code).to eq(plan_2.code)
          expect(new_subscription).to be_pending

          expect(Fee.where(invoice_id: nil, created_at: ...Time.current).count).to eq 2
          expect(Fee.where(invoice_id: nil, created_at: Time.current..).count).to eq 0
        end

        travel_to(DateTime.new(2024, 6, 19, 0, 0)) do
          send_event! "user_3"
          send_event! "user_4"
        end

        travel_to(DateTime.new(2024, 7, 1, 0, 10)) do
          perform_billing
          expect(Fee.where(invoice_id: nil, created_at: Time.current.beginning_of_month..).count).to eq 0
        end

        travel_to(DateTime.new(2024, 7, 1, 0, 10)) do
          perform_billing
          expect(Fee.where(invoice_id: nil, created_at: Time.current.beginning_of_month..).count).to eq 0
        end

        travel_to(DateTime.new(2024, 7, 4, 14)) do
          perform_billing
          expect(customer.subscriptions.order(created_at: :asc).first).to be_terminated
          new_subscription = customer.subscriptions.order(created_at: :asc).last
          expect(new_subscription.plan.code).to eq(plan_2.code)
          expect(new_subscription).to be_active
          expect(Fee.where(invoice_id: nil, created_at: Time.current.beginning_of_month..).count).to eq 4
        end
      end
    end
  end

  context "when testing the boundaries" do
    let(:invoiceable) { true }
    let(:pay_in_advance) { true }
    let(:grouped_by) { ["item_id"] }
    let(:plan_2) { create(:plan, organization:, name: "downgraded", amount_cents: 49.99, pay_in_advance: true) }

    let(:charge) do
      create(:charge, {
        plan:,
        billable_metric:,
        invoiceable: true,
        pay_in_advance: false,
        prorated: true,
        properties: {amount: "31", grouped_by:}
      })
    end

    before do
      create(:charge, {
        plan: plan_2,
        billable_metric:,
        invoiceable: true,
        pay_in_advance: false,
        prorated: true,
        properties: {amount: "60", grouped_by:}
      })
    end

    context "when all subscriptions are calendar" do
      let(:billing_time) { "calendar" }

      # this proves a bug :melting:
      # last invoice should have fee.charge.first.amount_cents == 31
      # because total we have 1 recurring unit that is active the whole month, so the total should be 31.
      # instead, it's 32
      it "performs subscription downgrade and billing correctly" do
        travel_to(DateTime.new(2024, 6, 1, 0, 0)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: external_subscription_id,
              plan_code: plan.code,
              billing_time:
            }
          )
          perform_billing
        end

        travel_to(DateTime.new(2024, 6, 15, 10, 5, 59)) do
          send_event! "user_2"
        end

        travel_to(DateTime.new(2024, 7, 1, 0, 0)) do
          perform_billing
        end

        travel_to(DateTime.new(2024, 7, 15, 10, 6)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: external_subscription_id,
              plan_code: plan_2.code,
              billing_time:
            }
          )

          expect(customer.subscriptions.order(created_at: :asc).first).to be_active
          expect(customer.invoices.count).to eq(2)
          new_subscription = customer.subscriptions.order(created_at: :asc).last
          expect(new_subscription.plan.code).to eq(plan_2.code)
          expect(new_subscription).to be_pending
          expect(Fee.where(created_at: ...Time.current, fee_type: "charge").count).to eq 1
          expect(Fee.where(created_at: Time.current.., fee_type: "charge").count).to eq 0
        end

        travel_to(DateTime.new(2024, 8, 1, 0, 0)) do
          perform_billing
          termination_invoice = customer.invoices.order(:created_at).last
          expect(termination_invoice.fees.charge.last.amount_cents).to eq(3100)
        end
      end
    end
  end
end
