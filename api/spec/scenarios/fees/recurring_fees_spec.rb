# frozen_string_literal: true

require "rails_helper"

describe "Recurring Non Invoiceable Fees" do
  let(:organization) { create(:organization, webhook_url: "http://fees.test/wh") }
  let(:billing_entity) { create(:billing_entity, organization:) }
  let(:customer) { create(:customer, organization:, billing_entity:) }
  let(:billable_metric) { create(:unique_count_billable_metric, :recurring, organization:, code: "seats") }
  let(:plan) { create(:plan, organization:, amount_cents: 49.99, pay_in_advance: true) }
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
  let(:subscription) { customer.subscriptions.first }

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

  context "when charge is pay in advance" do
    let(:pay_in_advance) { true }

    context "with invoiceable = false" do
      let(:invoiceable) { false }

      context "without grace period" do
        # rubocop:disable RSpec/ExpectInHook
        before do
          travel_to(Time.zone.parse("2024-06-05T12:12:00")) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: external_subscription_id,
                plan_code: plan.code
              }
            )
            perform_billing
            expect(customer.invoices.count).to eq(1)
          end

          (1..5).each do |i|
            travel_to(DateTime.new(2024, 6, 10 + i, 10)) do
              send_event! "user_#{i}"
              expect(subscription.fees.charge.count).to eq(i)
              expect(subscription.fees.charge.order(created_at: :desc).first.amount_cents).to eq((21 - i) * 100)
            end
          end
        end
        # rubocop:enable RSpec/ExpectInHook

        context "without grouped_by" do
          let(:grouped_by) { nil }

          it "creates one fee for all events", transaction: false do
            travel_to(Time.zone.parse("2024-07-01T00:10:00")) do # BILLING DAY !
              perform_billing

              expect(subscription.invoices.count).to eq 2

              recurring_fee = Fee.where(subscription:, charge:, created_at: Time.current.to_date..).sole
              expect(recurring_fee.units).to eq 5
              expect(recurring_fee.invoice_id).to be_nil
              expect(recurring_fee.amount_cents).to eq(30 * 5 * 100)
            end

            travel_to(Time.zone.parse("2024-07-12T01:10:00")) do
              send_event! "user_july_1"
              send_event! "user_july_2"
            end

            travel_to(Time.zone.parse("2024-08-01T01:10:00")) do # August BILLING DAY !
              expect(Fee.where(subscription:, charge:, created_at: Time.current.to_date..).count).to eq 0

              perform_billing

              expect(subscription.invoices.count).to eq 3

              expect(a_request(:post, "http://fees.test/wh").with(
                body: hash_including(webhook_type: "fee.created", fee: hash_including({
                  "units" => "7.0",
                  "from_date" => "2024-08-01T00:00:00+00:00",
                  "to_date" => "2024-08-31T23:59:59+00:00"
                }))
              )).to have_been_made.once

              recurring_fee = Fee.where(subscription:, charge:, created_at: Time.current.to_date..).sole
              expect(recurring_fee.units).to eq 7
              expect(recurring_fee.invoice_id).to be_nil
              expect(recurring_fee.amount_cents).to eq(30 * 7 * 100)
            end

            # Test termination of subscription
            travel_to(Time.zone.parse("2024-08-15T01:10:00")) do
              terminate_subscription(subscription)
              perform_billing
              expect(subscription.reload).to be_terminated
              expect(subscription.invoices.count).to eq 4
              recurring_fee = Fee.where(subscription:, charge:, created_at: Time.current.beginning_of_month..).sole
              expect(recurring_fee.units).to eq 7
              expect(recurring_fee.invoice_id).to be_nil
              expect(recurring_fee.amount_cents).to eq(30 * 7 * 100)
            end
          end
        end

        context "with grouped_by on unique field_name" do
          let(:grouped_by) { ["item_id"] }

          it "creates a fee per event" do
            travel_to(Time.zone.parse("2024-07-01T00:10:00")) do # July BILLING DAY !
              expect(Fee.where(subscription:, charge:, created_at: Time.current.to_date..).count).to eq 0

              perform_billing
              expect(subscription.invoices.count).to eq 2

              recurring_fees = Fee.where(subscription:, charge:, created_at: Time.current.to_date..)
              expect(recurring_fees.count).to eq 5
              expect(recurring_fees).to all(have_attributes(units: 1, invoice_id: nil, pay_in_advance: true, amount_cents: 30 * 100))
            end

            travel_to(Time.zone.parse("2024-07-12T01:10:00")) do
              send_event! "user_july_1"
              send_event! "user_july_2"
            end

            travel_to(Time.zone.parse("2024-08-01T01:10:00")) do # August BILLING DAY !
              expect(Fee.where(subscription:, charge:, created_at: Time.current.to_date..).count).to eq 0

              WebMock.reset_executed_requests!

              perform_billing
              expect(subscription.invoices.count).to eq 3

              expect(a_request(:post, "http://fees.test/wh").with(
                body: hash_including(webhook_type: "fee.created", fee: hash_including({
                  "lago_invoice_id" => nil,
                  "units" => "1.0",
                  "from_date" => "2024-08-01T00:00:00+00:00",
                  "to_date" => "2024-08-31T23:59:59+00:00"
                }))
              )).to have_been_made.times(7)

              recurring_fees = Fee.where(subscription:, charge:, created_at: Time.current.to_date..)
              expect(recurring_fees.count).to eq 7
              expect(recurring_fees).to all(have_attributes(units: 1, invoice_id: nil, pay_in_advance: true, amount_cents: 30 * 100))
            end

            # Test termination of subscription
            travel_to(Time.zone.parse("2024-08-15T01:10:00")) do
              terminate_subscription(subscription)
              perform_billing
              expect(subscription.reload).to be_terminated
              expect(subscription.invoices.count).to eq 4
              recurring_fees = Fee.where(subscription:, charge:, created_at: Time.current.beginning_of_month..)
              expect(recurring_fees.count).to eq(7)
              expect(recurring_fees).to all(have_attributes(units: 1, invoice_id: nil, pay_in_advance: true, amount_cents: 30 * 100))
            end
          end
        end
      end

      context "with grace period" do
        let(:organization) { create(:organization, webhook_url: "http://fees.test/wh") }
        let(:billing_entity) { create(:billing_entity, organization:, invoice_grace_period: 3) }
        let(:grouped_by) { ["item_id"] }

        it "creates the recurring fees without the grace period" do
          travel_to(Time.zone.parse("2024-06-05T12:12:00")) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: external_subscription_id,
                plan_code: plan.code
              }
            )
            perform_billing
            expect(customer.invoices.draft.count).to eq(1)
          end

          travel_to(DateTime.new(2024, 6, 10, 10)) do
            send_event! "user_1"
            send_event! "user_2"
            expect(subscription.fees.charge.where(invoice_id: nil).count).to eq(2)
            expect(subscription.fees.charge.order(created_at: :desc)).to all(have_attributes(amount_cents: 2100))
          end

          travel_to(Time.zone.parse("2024-07-01T00:10:00")) do # July BILLING DAY !
            expect(Fee.where(subscription:, charge:, created_at: Time.current.to_date..).count).to eq 0

            WebMock.reset_executed_requests!
            perform_billing

            expect(a_request(:post, "http://fees.test/wh").with(
              body: hash_including(webhook_type: "fee.created", fee: hash_including({
                "lago_invoice_id" => nil,
                "units" => "1.0",
                "from_date" => "2024-07-01T00:00:00+00:00",
                "to_date" => "2024-07-31T23:59:59+00:00"
              }))
            )).to have_been_made.times(2)

            expect(subscription.invoices.draft.count).to eq 2
            expect(subscription.invoices).to all(have_attributes(status: "draft"))

            recurring_fees = Fee.where(subscription:, charge:, created_at: Time.current.beginning_of_month..)
            expect(recurring_fees.count).to eq 2
            expect(recurring_fees).to all(have_attributes(units: 1, invoice_id: nil, pay_in_advance: true, amount_cents: 30 * 100))
          end

          travel_to(Time.zone.parse("2024-07-04T01:10:00")) do
            WebMock.reset_executed_requests!
            perform_finalize_refresh

            expect(a_request(:post, "http://fees.test/wh").with(
              body: hash_including(webhook_type: "fee.created", fee: hash_including({
                "lago_invoice_id" => nil
              }))
            )).not_to have_been_made

            expect(subscription.invoices.draft.count).to eq 0
            expect(subscription.invoices.finalized.count).to eq 2
            expect(Fee.where(subscription:, charge:, created_at: Time.current.beginning_of_month..).count).to eq 2
          end

          # Test termination of subscription
          travel_to(Time.zone.parse("2024-07-05T01:30:00")) do
            terminate_subscription(subscription)
            perform_billing
            expect(subscription.reload).to be_terminated
            expect(subscription.invoices.draft.count).to eq 1
            expect(subscription.invoices.finalized.count).to eq 2
            expect(Fee.where(subscription:, charge:, created_at: Time.current.beginning_of_month..).count).to eq 2
          end
        end
      end
    end

    context "with invoiceable = true" do
      let(:invoiceable) { true }

      # rubocop:disable RSpec/ExpectInHook
      before do
        travel_to(Time.zone.parse("2024-06-05T12:12:00")) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: external_subscription_id,
              plan_code: plan.code
            }
          )
          perform_billing
          expect(customer.invoices.count).to eq(1)
        end

        (1..5).each do |i|
          travel_to(DateTime.new(2024, 6, 10 + i, 10)) do
            send_event! "user_#{i}"
            expect(subscription.invoices.count).to eq(i + 1)
            expect(subscription.invoices.order(created_at: :desc).first.fees.sole.amount_cents).to eq((21 - i) * 100)
          end
        end
      end
      # rubocop:enable RSpec/ExpectInHook

      context "without grouped_by" do
        let(:grouped_by) { nil }

        it "creates one fee for all events", transaction: false do
          travel_to(Time.zone.parse("2024-07-01T00:10:00")) do # BILLING DAY !
            perform_billing

            expect(subscription.invoices.count).to eq 7

            renewal_invoice = subscription.invoices.order(created_at: :desc).first
            recurring_fee = renewal_invoice.fees.charge.sole
            expect(recurring_fee.units).to eq 5
            expect(recurring_fee.pay_in_advance).to be_falsey
            expect(recurring_fee.amount_cents).to eq(30 * 5 * 100)
          end

          # Test termination of subscription
          travel_to(Time.zone.parse("2024-07-15T01:10:00")) do
            terminate_subscription(subscription)
            perform_billing
            expect(subscription.reload).to be_terminated
            renewal_invoice = subscription.invoices.order(created_at: :desc).first
            recurring_fees = renewal_invoice.fees.charge
            expect(recurring_fees.count).to eq 0
          end
        end
      end

      context "with grouped_by on unique field_name" do
        let(:grouped_by) { ["item_id"] }

        it "creates a fee per event" do
          travel_to(Time.zone.parse("2024-07-01T00:10:00")) do # BILLING DAY !
            perform_billing

            expect(subscription.invoices.count).to eq 7

            recurring_fees = Fee.where(subscription:, charge:, created_at: Time.current.to_date..)
            expect(recurring_fees.count).to eq 5

            renewal_invoice = subscription.invoices.order(created_at: :desc).first
            recurring_fees = renewal_invoice.fees.charge
            expect(recurring_fees.count).to eq 5
            expect(recurring_fees).to all(have_attributes(units: 1, pay_in_advance: false, amount_cents: 30 * 100))
          end

          # Test termination of subscription
          travel_to(Time.zone.parse("2024-07-15T01:10:00")) do
            terminate_subscription(subscription)
            perform_billing
            expect(subscription.reload).to be_terminated
            renewal_invoice = subscription.invoices.order(created_at: :desc).first
            recurring_fees = renewal_invoice.fees.charge
            expect(recurring_fees.count).to eq 0
          end
        end
      end
    end
  end

  context "when charge is pay in arrears" do
    let(:pay_in_advance) { false }

    context "with invoiceable = true" do
      let(:invoiceable) { true }

      # rubocop:disable RSpec/ExpectInHook
      before do
        travel_to(Time.zone.parse("2024-06-05T12:12:00")) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: external_subscription_id,
              plan_code: plan.code
            }
          )
          perform_billing
          expect(customer.invoices.count).to eq(1)
        end

        (1..5).each do |i|
          travel_to(DateTime.new(2024, 6, 10 + i, 10)) do
            send_event! "user_#{i}"
          end
        end
        expect(subscription.invoices.count).to eq 1
      end
      # rubocop:enable RSpec/ExpectInHook

      context "without grouped_by" do
        let(:grouped_by) { nil }

        it "creates one fee for all events", transaction: false do
          travel_to(Time.zone.parse("2024-07-01T00:10:00")) do # BILLING DAY !
            perform_billing

            expect(subscription.invoices.count).to eq 2

            renewal_invoice = subscription.invoices.order(created_at: :desc).first
            recurring_fee = renewal_invoice.fees.charge.sole
            expect(recurring_fee.units).to eq 5
            expect(recurring_fee.pay_in_advance).to be_falsey
            expect(recurring_fee.amount_cents).to eq((20 + 19 + 18 + 17 + 16) * 100)
          end

          # Test termination of subscription
          travel_to(Time.zone.parse("2024-07-15T01:10:00")) do
            terminate_subscription(subscription)
            perform_billing
            expect(subscription.reload).to be_terminated
            renewal_invoice = subscription.invoices.order(created_at: :desc).first
            recurring_fee = renewal_invoice.fees.charge.sole
            expect(recurring_fee.units).to eq 5
            expect(recurring_fee.pay_in_advance).to be_falsey
            expect(recurring_fee.amount_cents).to eq(7258)
          end
        end
      end

      context "with grouped_by on unique field_name" do
        let(:grouped_by) { ["item_id"] }

        it "creates a fee per event" do
          travel_to(Time.zone.parse("2024-07-01T00:10:00")) do # BILLING DAY !
            perform_billing

            expect(subscription.invoices.count).to eq 2

            recurring_fees = Fee.where(subscription:, charge:, created_at: Time.current.to_date..)
            expect(recurring_fees.count).to eq 5

            renewal_invoice = subscription.invoices.order(created_at: :desc).first
            recurring_fees = renewal_invoice.fees.charge
            expect(recurring_fees.count).to eq 5
            expect(recurring_fees).to all(have_attributes(units: 1, pay_in_advance: false))
            expect(recurring_fees.map(&:amount_cents).sort).to eq([20, 19, 18, 17, 16].sort.map { |i| i * 100 })
          end

          # Test termination of subscription
          travel_to(Time.zone.parse("2024-07-15T01:10:00")) do
            terminate_subscription(subscription)
            perform_billing
            expect(subscription.reload).to be_terminated
            expect(subscription.invoices.count).to eq 3
            termination_invoice = subscription.invoices.order(created_at: :desc).first
            recurring_fees = termination_invoice.fees.charge
            expect(recurring_fees.count).to eq 5
            expect(recurring_fees).to all(have_attributes(units: 1, pay_in_advance: false))
            expect(recurring_fees.map(&:amount_cents).sort).to eq([1452, 1452, 1452, 1452, 1452])
          end
        end
      end
    end
  end
end
