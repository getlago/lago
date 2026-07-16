# frozen_string_literal: true

require "rails_helper"

describe "Billing Minimum Commitments In Advance Scenario" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:timezone) { "UTC" }
  let(:customer) { create(:customer, organization:, timezone:, currency: "EUR") }

  let(:plan) do
    create(
      :plan,
      organization:,
      amount_cents: 100_000,
      amount_currency: "EUR",
      interval: plan_interval,
      pay_in_advance: true,
      bill_charges_monthly:
    )
  end

  let(:bill_charges_monthly) { false }
  let(:invoice) { subscription.reload.invoices.order(sequential_id: :desc).first }
  let(:subscription) { customer.subscriptions.first.reload }

  before do
    minimum_commitment

    # Create the subscription
    travel_to(subscription_time) do
      create_subscription(
        {
          external_customer_id: customer.external_id,
          external_id: customer.external_id,
          plan_code: plan.code,
          billing_time:
        }
      )

      perform_billing
    end
  end

  context "when plan is billed in advance" do
    context "with weekly plan" do
      let(:plan_interval) { "weekly" }

      context "with calendar billing" do
        let(:billing_time) { "calendar" }
        let(:subscription_time) { DateTime.new(2023, 2, 1) }
        let(:commitment_fee_amount_cents) { 642_857 }

        context "when there is no previous period" do
          context "when plan has no minimum commitment" do
            let(:minimum_commitment) { nil }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is not reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end
        end

        context "when there is a previous period" do
          let(:current_period_start) { DateTime.new(2023, 2, 6, 10) }

          before do
            travel_to(current_period_start)

            perform_billing
          end

          context "when plan has no minimum commitment" do
            let(:minimum_commitment) { nil }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is not reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

            it "creates an invoice with minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(1)
              expect(invoice.fees.commitment.first.amount_cents).to eq(commitment_fee_amount_cents)
            end

            context "when subscription is terminated" do
              let(:invoices) { Invoice.order(:sequential_id) }
              let(:commitment_fees) { Fee.commitment.pluck(:amount_cents) }

              before do
                travel_to(DateTime.new(2023, 2, 13, 10))
                perform_billing

                travel_to(DateTime.new(2023, 2, 15, 10))
                terminate_subscription(subscription)
                perform_all_enqueued_jobs
              end

              it "creates an invoice with minimum commitment fee" do
                expect(invoices.first.fees.commitment.count).to eq(0)
                expect(invoices.second.fees.commitment.count).to eq(1)
                expect(invoices.third.fees.commitment.count).to eq(1)
                expect(invoices.fourth.fees.commitment.count).to eq(1)

                expect(commitment_fees).to contain_exactly(328_571, 642_857, 900_000)
              end
            end
          end
        end
      end

      context "with anniversary billing" do
        let(:billing_time) { "anniversary" }
        let(:subscription_time) { DateTime.new(2023, 2, 1) }
        let(:commitment_fee_amount_cents) { 900_000 }

        context "when there is no previous period" do
          context "when plan has no minimum commitment" do
            let(:minimum_commitment) { nil }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is not reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end
        end

        context "when there is a previous period" do
          let(:current_period_start) { DateTime.new(2023, 2, 8, 10) }

          before do
            travel_to(current_period_start)

            perform_billing
          end

          context "when plan has no minimum commitment" do
            let(:minimum_commitment) { nil }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is not reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

            it "creates an invoice with minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(1)
              expect(invoice.fees.commitment.first.amount_cents).to eq(commitment_fee_amount_cents)
            end
          end
        end
      end
    end

    context "with monthly plan" do
      let(:plan_interval) { "monthly" }

      context "with calendar billing" do
        let(:billing_time) { "calendar" }
        let(:subscription_time) { DateTime.new(2023, 2, 4) }
        let(:commitment_fee_amount_cents) { 803_571 }

        context "when there is no previous period" do
          context "when plan has no minimum commitment" do
            let(:minimum_commitment) { nil }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is not reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end
        end

        context "when there is a previous period" do
          let(:current_period_start) { DateTime.new(2023, 3, 1, 10) }

          before do
            travel_to(current_period_start)

            perform_billing
          end

          context "when plan has no minimum commitment" do
            let(:minimum_commitment) { nil }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is not reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

            it "creates an invoice with minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(1)
              expect(invoice.fees.commitment.first.amount_cents).to eq(commitment_fee_amount_cents)
            end
          end
        end
      end

      context "with anniversary billing" do
        let(:billing_time) { "anniversary" }
        let(:subscription_time) { DateTime.new(2023, 2, 4) }
        let(:commitment_fee_amount_cents) { 900_000 }

        context "when there is no previous period" do
          context "when plan has no minimum commitment" do
            let(:minimum_commitment) { nil }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is not reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end
        end

        context "when there is a previous period" do
          let(:current_period_start) { DateTime.new(2023, 3, 4, 10) }

          before do
            travel_to(current_period_start)

            perform_billing
          end

          context "when plan has no minimum commitment" do
            let(:minimum_commitment) { nil }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is not reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

            it "creates an invoice with minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(1)
              expect(invoice.fees.commitment.first.amount_cents).to eq(commitment_fee_amount_cents)
            end
          end
        end
      end
    end

    context "with quarterly plan" do
      let(:plan_interval) { "quarterly" }

      context "with calendar billing" do
        let(:billing_time) { "calendar" }
        let(:subscription_time) { DateTime.new(2023, 2, 4) }
        let(:commitment_fee_amount_cents) { 560_000 }

        context "when there is no previous period" do
          context "when plan has no minimum commitment" do
            let(:minimum_commitment) { nil }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is not reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end
        end

        context "when there is a previous period" do
          let(:current_period_start) { DateTime.new(2023, 4, 1, 10) }

          before do
            travel_to(current_period_start)

            perform_billing
          end

          context "when plan has no minimum commitment" do
            let(:minimum_commitment) { nil }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is not reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

            it "creates an invoice with minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(1)
              expect(invoice.fees.commitment.first.amount_cents).to eq(commitment_fee_amount_cents)
            end
          end
        end
      end

      context "with anniversary billing" do
        let(:billing_time) { "anniversary" }
        let(:subscription_time) { DateTime.new(2023, 2, 4) }
        let(:commitment_fee_amount_cents) { 900_000 }

        context "when there is no previous period" do
          context "when plan has no minimum commitment" do
            let(:minimum_commitment) { nil }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is not reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end
        end

        context "when there is a previous period" do
          let(:current_period_start) { DateTime.new(2023, 5, 4, 10) }

          before do
            travel_to(current_period_start)

            perform_billing
          end

          context "when plan has no minimum commitment" do
            let(:minimum_commitment) { nil }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

            it "creates an invoice without minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(0)
            end
          end

          context "when minimum commitment amount is not reached" do
            let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

            it "creates an invoice with minimum commitment fee" do
              expect(invoice.fees.commitment.count).to eq(1)
              expect(invoice.fees.commitment.first.amount_cents).to eq(commitment_fee_amount_cents)
            end
          end
        end
      end
    end

    context "with yearly plan and yearly charge" do
      let(:plan_interval) { "yearly" }

      context "with calendar billing" do
        let(:billing_time) { "calendar" }
        let(:subscription_time) { DateTime.new(2022, 2, 1) }
        let(:commitment_fee_amount_cents) { 823_561 }

        context "when plan is charged yearly" do
          context "when there is no previous period" do
            context "when plan has no minimum commitment" do
              let(:minimum_commitment) { nil }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end

            context "when minimum commitment amount is reached" do
              let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end

            context "when minimum commitment amount is not reached" do
              let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end
          end

          context "when there is a previous period" do
            let(:current_period_start) { DateTime.new(2023, 1, 1, 10) }

            before do
              travel_to(current_period_start)

              perform_billing
            end

            context "when plan has no minimum commitment" do
              let(:minimum_commitment) { nil }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end

            context "when minimum commitment amount is reached" do
              let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end

            context "when minimum commitment amount is not reached" do
              let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

              it "creates an invoice with minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(1)
                expect(invoice.fees.commitment.first.amount_cents).to eq(commitment_fee_amount_cents)
              end
            end
          end
        end

        context "when plan is charged monthly" do
          let(:bill_charges_monthly) { true }

          context "when there is no previous period" do
            context "when plan has no minimum commitment" do
              let(:minimum_commitment) { nil }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end

            context "when minimum commitment amount is reached" do
              let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end

            context "when minimum commitment amount is not reached" do
              let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end
          end

          context "when there is a previous period" do
            let(:current_period_start) { DateTime.new(2023, 1, 1, 10) }

            before do
              travel_to(current_period_start)

              perform_billing
            end

            context "when plan has no minimum commitment" do
              let(:minimum_commitment) { nil }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end

            context "when minimum commitment amount is reached" do
              let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end

            context "when minimum commitment amount is not reached" do
              let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

              it "creates an invoice with minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(1)
                expect(invoice.fees.commitment.first.amount_cents).to eq(commitment_fee_amount_cents)
              end
            end
          end
        end
      end

      context "with anniversary billing" do
        let(:billing_time) { "anniversary" }
        let(:subscription_time) { DateTime.new(2022, 2, 4) }
        let(:commitment_fee_amount_cents) { 900_000 }

        context "when plan is charged yearly" do
          context "when there is no previous period" do
            context "when plan has no minimum commitment" do
              let(:minimum_commitment) { nil }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end

            context "when minimum commitment amount is reached" do
              let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end

            context "when minimum commitment amount is not reached" do
              let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end
          end

          context "when there is a previous period" do
            let(:current_period_start) { DateTime.new(2023, 2, 4, 10) }

            before do
              travel_to(current_period_start)

              perform_billing
            end

            context "when plan has no minimum commitment" do
              let(:minimum_commitment) { nil }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end

            context "when minimum commitment amount is reached" do
              let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end

            context "when minimum commitment amount is not reached" do
              let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

              it "creates an invoice with minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(1)
                expect(invoice.fees.commitment.first.amount_cents).to eq(commitment_fee_amount_cents)
              end
            end
          end
        end

        context "when plan is charged monthly" do
          let(:bill_charges_monthly) { true }

          context "when there is no previous period" do
            context "when plan has no minimum commitment" do
              let(:minimum_commitment) { nil }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end

            context "when minimum commitment amount is reached" do
              let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end

            context "when minimum commitment amount is not reached" do
              let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end
          end

          context "when there is a previous period" do
            let(:current_period_start) { DateTime.new(2023, 2, 4, 10) }

            before do
              travel_to(current_period_start)

              perform_billing
            end

            context "when plan has no minimum commitment" do
              let(:minimum_commitment) { nil }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end

            context "when minimum commitment amount is reached" do
              let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

              it "creates an invoice without minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(0)
              end
            end

            context "when minimum commitment amount is not reached" do
              let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

              it "creates an invoice with minimum commitment fee" do
                expect(invoice.fees.commitment.count).to eq(1)
                expect(invoice.fees.commitment.first.amount_cents).to eq(commitment_fee_amount_cents)
              end
            end
          end
        end
      end
    end
  end
end
