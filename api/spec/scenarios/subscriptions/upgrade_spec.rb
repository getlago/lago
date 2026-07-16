# frozen_string_literal: true

require "rails_helper"

describe "Subscription Upgrade Scenario", transaction: false do
  let(:organization) { create(:organization, webhook_url: false, email_settings: []) }

  let(:customer) { create(:customer, organization:) }

  let(:monthly_plan) do
    create(
      :plan,
      organization:,
      interval: "monthly",
      amount_cents: 1000,
      pay_in_advance: true
    )
  end

  let(:yearly_plan) do
    create(
      :plan,
      organization:,
      interval: "yearly",
      amount_cents: 12_000,
      pay_in_advance: true
    )
  end

  let(:subscription_at) { DateTime.new(2023, 6, 29, 12, 12) }

  it "upgrades and bill subscriptions on a regular basis" do
    subscription = nil

    # NOTE: Jun 29th: create the subscription
    travel_to(subscription_at) do
      create_subscription(
        {
          external_customer_id: customer.external_id,
          external_id: customer.external_id,
          plan_code: monthly_plan.code,
          billing_time: "anniversary",
          subscription_at: subscription_at.iso8601
        }
      )

      subscription = customer.subscriptions.first
      expect(subscription).to be_active
      expect(subscription.invoices.count).to eq(1)

      invoice = subscription.invoices.last
      expect(invoice.fees_amount_cents).to eq(monthly_plan.amount_cents)
      expect(invoice.invoice_subscriptions.first.from_datetime.iso8601).to eq("2023-06-29T00:00:00Z")
      expect(invoice.invoice_subscriptions.first.to_datetime.iso8601).to eq("2023-07-28T23:59:59Z")
    end

    # NOTE: July 29th: Bill subscription
    travel_to(DateTime.new(2023, 7, 29, 12, 12)) do
      expect { perform_billing }.to change { subscription.reload.invoices.count }

      expect(subscription.invoices.count).to eq(2)

      invoice = subscription.invoices.order(created_at: :asc).last
      expect(invoice.fees_amount_cents).to eq(monthly_plan.amount_cents)
      expect(invoice.invoice_subscriptions.first.from_datetime.iso8601).to eq("2023-07-29T00:00:00Z")
      expect(invoice.invoice_subscriptions.first.to_datetime.iso8601).to eq("2023-08-28T23:59:59Z")
      expect(invoice.invoice_subscriptions.first.charges_from_datetime.iso8601).to eq("2023-06-29T12:12:00Z")
      expect(invoice.invoice_subscriptions.first.charges_to_datetime.iso8601).to eq("2023-07-28T23:59:59Z")
    end

    # NOTE: August 29th: Bill subscription
    travel_to(DateTime.new(2023, 8, 29, 12, 12)) do
      expect { perform_billing }.to change { subscription.reload.invoices.count }

      expect(subscription.invoices.count).to eq(3)

      invoice = subscription.invoices.order(created_at: :asc).last
      expect(invoice.fees_amount_cents).to eq(monthly_plan.amount_cents)
      expect(invoice.invoice_subscriptions.first.from_datetime.iso8601).to eq("2023-08-29T00:00:00Z")
      expect(invoice.invoice_subscriptions.first.to_datetime.iso8601).to eq("2023-09-28T23:59:59Z")
      expect(invoice.invoice_subscriptions.first.charges_from_datetime.iso8601).to eq("2023-07-29T00:00:00Z")
      expect(invoice.invoice_subscriptions.first.charges_to_datetime.iso8601).to eq("2023-08-28T23:59:59Z")
    end

    # NOTE: On september 28th: Upgrade to the yearly plan
    travel_to(DateTime.new(2023, 9, 28, 5, 0)) do
      create_subscription(
        {
          external_customer_id: customer.external_id,
          external_id: customer.external_id,
          plan_code: yearly_plan.code,
          billing_time: "anniversary"
        }
      )

      expect(subscription.reload).to be_terminated
      expect(subscription.invoices.count).to eq(4)
      expect(customer.invoices.count).to eq(4)

      # expect(invoice.invoice_subscriptions.first.from_datetime.iso8601).to eq('2023-08-29T00:00:00Z')
      # expect(invoice.invoice_subscriptions.first.to_datetime.iso8601).to eq('2023-09-28T23:59:59Z')
      expect(subscription.invoice_subscriptions.order(created_at: :desc).first.charges_from_datetime.iso8601)
        .to eq("2023-08-29T00:00:00Z")
      expect(subscription.invoice_subscriptions.order(created_at: :desc).first.charges_to_datetime.iso8601)
        .to eq("2023-09-28T05:00:00Z")

      new_subscription = customer.subscriptions.order(created_at: :asc).last
      expect(new_subscription.plan.code).to eq(yearly_plan.code)
      expect(new_subscription).to be_active
      expect(new_subscription.invoices.count).to eq(1)

      invoice = new_subscription.invoices.last

      expect(customer.credit_notes.first.credit_amount_cents).to eq(32) # 1000 / 31

      number_of_days = (DateTime.new(2024, 6, 29, 0, 0) - DateTime.new(2023, 9, 28, 0, 0)).to_i
      single_day_price = 12_000.fdiv(366)

      expect(invoice.fees_amount_cents).to eq((number_of_days * single_day_price).round)
    end
  end

  context "when there are fixed charges" do
    let(:plan) { create(:plan, :monthly, pay_in_advance: false, amount_cents: 100, organization:) }
    let(:plan_upgrade) { create(:plan, :monthly, pay_in_advance: false, amount_cents: 10000, organization:) }
    let(:add_ons) { create_list(:add_on, 3, organization:) }
    let(:fixed_charges_plan) {
      [
        create(:fixed_charge, plan:, add_on: add_ons[0], properties: {amount: "1"}, units: 10, pay_in_advance:, prorated:),
        create(:fixed_charge, plan:, add_on: add_ons[1], properties: {amount: "3"}, units: 5, pay_in_advance:, prorated:)
      ]
    }
    let(:fixed_charges_plan_upgrade) {
      [
        create(:fixed_charge, plan: plan_upgrade, add_on: add_ons[1], properties: {amount: "10"}, units: 10, pay_in_advance:, prorated:),
        create(:fixed_charge, plan: plan_upgrade, add_on: add_ons[2], properties: {amount: "20"}, units: 1, pay_in_advance:, prorated:)
      ]
    }
    let(:subscription_at) { DateTime.new(2023, 7, 19, 12, 12) }

    before do
      fixed_charges_plan
      fixed_charges_plan_upgrade
    end

    context "when fixed charges are in_advance" do
      let(:pay_in_advance) { true }

      context "when fixed charges are prorated" do
        # In this case we have fixed_charges that were paid_in advance in the previous subscription
        # so they were already partially paid. When prorating new subscription charges, we should take in account the
        # already paid amount
        let(:prorated) { true }

        it "calculates all fees" do
          # 2023, 7, 19, 12, 12
          travel_to(subscription_at) do
            create_subscription({
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code,
              billing_time: "calendar"
            })
          end
          subscription = customer.subscriptions.first
          expect(subscription).to be_active
          expect(subscription.invoices.count).to eq(1)
          invoice = subscription.invoices.first
          expect(invoice.fees.fixed_charge.count).to eq(2)
          # prorated in advance - created immediately
          expect(invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([1000 * 13 / 31, 1500 * 13 / 31])
          expect(invoice.fees.fixed_charge.sample.properties).to include(
            "fixed_charges_from_datetime" => "2023-07-19T12:12:00.000Z",
            "fixed_charges_to_datetime" => "2023-07-31T23:59:59.999Z"
          )
          travel_to(DateTime.new(2023, 8, 1, 0, 0)) do
            expect { perform_billing }.to change { subscription.reload.invoices.count }.from(1).to(2)
          end

          invoice = subscription.invoices.order(created_at: :asc).last
          expect(invoice.fees.fixed_charge.count).to eq(2)
          # prorated in advance - created at the beginning of the month
          expect(invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([1000, 1500])
          expect(invoice.fees.fixed_charge.sample.properties).to include(
            "fixed_charges_from_datetime" => "2023-08-01T00:00:00.000Z",
            "fixed_charges_to_datetime" => "2023-08-31T23:59:59.999Z"
          )

          travel_to(DateTime.new(2023, 8, 21, 12, 0, 0)) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan_upgrade.code,
                billing_time: "calendar"
              }
            )

            expect(subscription.reload).to be_terminated
            expect(subscription.invoices.count).to eq(3)
            new_subscription = subscription.reload.next_subscription
            # it a new invoice with charges for old subscription - pay_in_arrears subscription fee +
            # prorated charges for the new plan
            invoice = subscription.invoices.order(:created_at).last
            expect(invoice.invoice_subscriptions.count).to eq(2)
            expect(invoice.invoice_subscriptions.map(&:subscription)).to match_array([subscription, new_subscription])
            expect(invoice.fees.subscription.count).to eq(1)
            expect(invoice.fees.subscription.map(&:amount_cents)).to match_array([(100 * 20 / 31.0).round])
          end
          new_subscription = subscription.reload.next_subscription
          expect(new_subscription).to be_active
          expect(new_subscription.invoices.count).to be(1)
          invoice = new_subscription.invoices.first
          expect(invoice.fees.fixed_charge.count).to eq(2)
          # old_plan:
          # create(:fixed_charge, plan:, add_on: add_ons[1], properties: {amount: "3"}, units: 5, pay_in_advance:, prorated:)
          # new_plan:
          # create(:fixed_charge, plan: plan_upgrade, add_on: add_ons[1], properties: {amount: "10"}, units: 10, pay_in_advance:, prorated:),
          # fixed_charge for add_on 1 was already prorated in the beginning of month for the full month,
          # 1500 has been paid, but it was only actually active 20 days. so when prorating the same add_on
          # with the new price we should deduct the amount that was already paid (remaining of already paid amount)
          prorated_new_price = (10000 * 11 / 31.0).round
          already_paid_for_this_period_this_charge = (1500 * 11 / 31.0).round
          left_to_pay_existing_addon = prorated_new_price - already_paid_for_this_period_this_charge
          expect(invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([left_to_pay_existing_addon, (2000 * 11 / 31.0).round])
          expect(invoice.fees.fixed_charge.sample.properties).to include(
            "fixed_charges_from_datetime" => "2023-08-21T12:00:00.000Z",
            "fixed_charges_to_datetime" => "2023-08-31T23:59:59.999Z"
          )

          travel_to(DateTime.new(2023, 9, 1, 0, 0)) do
            # Now we do charge the full month, as it's pay in advance
            expect { perform_billing }.to change { new_subscription.reload.invoices.count }.from(1).to(2)
            new_sub_invoice = new_subscription.invoices.order(created_at: :asc).last
            expect(new_sub_invoice.fees.fixed_charge.count).to eq(2)
            expect(new_sub_invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([10000, 2000])
            expect(new_sub_invoice.fees.fixed_charge.sample.properties).to include(
              "fixed_charges_from_datetime" => "2023-09-01T00:00:00.000Z",
              "fixed_charges_to_datetime" => "2023-09-30T23:59:59.999Z"
            )
          end
        end

        context "when upgrade happens at the same day when sub starts" do
          let(:subscription_at) { DateTime.new(2025, 12, 22, 12, 12) }

          it "calculates all fees" do
            travel_to(subscription_at) do
              create_subscription({
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code,
                billing_time: "calendar"
              })
            end
            subscription = customer.subscriptions.first
            expect(subscription).to be_active
            expect(subscription.invoices.count).to eq(1)
            invoice = subscription.invoices.first
            expect(invoice.fees.fixed_charge.count).to eq(2)
            # create(:fixed_charge, plan:, add_on: add_ons[0], properties: {amount: "1"}, units: 10, pay_in_advance:, prorated:),
            # create(:fixed_charge, plan:, add_on: add_ons[1], properties: {amount: "3"}, units: 5, pay_in_advance:, prorated:)
            expect(invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([(1000.0 * 10 / 31).round, (1500.0 * 10 / 31).round])
            expect(invoice.fees.fixed_charge.sample.properties).to include(
              "fixed_charges_from_datetime" => "2025-12-22T12:12:00.000Z",
              "fixed_charges_to_datetime" => "2025-12-31T23:59:59.999Z"
            )

            travel_to(subscription_at + 1.hour) do
              create_subscription(
                {
                  external_customer_id: customer.external_id,
                  external_id: customer.external_id,
                  plan_code: plan_upgrade.code,
                  billing_time: "calendar"
                }
              )
            end
            expect(subscription.reload).to be_terminated
            expect(subscription.invoices.count).to eq(2)
            new_subscription = subscription.reload.next_subscription
            expect(new_subscription).to be_active
            expect(new_subscription.invoices.count).to be(1)
            invoice = new_subscription.invoices.first
            expect(invoice.fees.fixed_charge.count).to eq(2)
            # create(:fixed_charge, plan: plan_upgrade, add_on: add_ons[1], properties: {amount: "10"}, units: 10, pay_in_advance:, prorated:),
            # create(:fixed_charge, plan: plan_upgrade, add_on: add_ons[2], properties: {amount: "20"}, units: 1, pay_in_advance:, prorated:)
            # old fee was prorated for the same number of days, so we fully deduct it
            old_fee_prorated_amount = (1500.0 * 10 / 31).round
            expect(invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([(10000.0 * 10 / 31).round - old_fee_prorated_amount, 2000 * 10 / 31])
            expect(invoice.fees.fixed_charge.sample.properties).to include(
              "fixed_charges_from_datetime" => "2025-12-22T13:12:00.000Z",
              "fixed_charges_to_datetime" => "2025-12-31T23:59:59.999Z"
            )
          end
        end

        context "when original fee was prorated for less than a month" do
          let(:subscription_at) { DateTime.new(2025, 12, 10, 12, 12) }
          let(:upgrade_at) { DateTime.new(2025, 12, 22, 12, 12) }

          it "calculates all fees" do
            travel_to(subscription_at) do
              create_subscription({
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code,
                billing_time: "calendar"
              })
            end
            subscription = customer.subscriptions.first
            expect(subscription).to be_active
            expect(subscription.invoices.count).to eq(1)
            invoice = subscription.invoices.first
            expect(invoice.fees.fixed_charge.count).to eq(2)
            expect(invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([(1000.0 * 22 / 31).round, (1500.0 * 22 / 31).round])
            expect(invoice.fees.fixed_charge.sample.properties).to include(
              "fixed_charges_from_datetime" => "2025-12-10T12:12:00.000Z",
              "fixed_charges_to_datetime" => "2025-12-31T23:59:59.999Z"
            )
            travel_to(upgrade_at) do
              create_subscription(
                {
                  external_customer_id: customer.external_id,
                  external_id: customer.external_id,
                  plan_code: plan_upgrade.code,
                  billing_time: "calendar"
                }
              )
            end
            expect(subscription.reload).to be_terminated
            expect(subscription.invoices.count).to eq(2)
            new_subscription = subscription.reload.next_subscription
            expect(new_subscription).to be_active
            expect(new_subscription.invoices.count).to be(1)
            invoice = new_subscription.invoices.first
            expect(invoice.fees.fixed_charge.count).to eq(2)
            # old fee was prorated for 22 days out of 31, so we need to get "price of one day" and multiply by the number of days in the new period
            old_fee_prorated_amount = (1500.0 * 22 / 31).round
            old_fee_covers_current_period = (old_fee_prorated_amount * 10.0 / 22).round
            expect(invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([(10000.0 * 10 / 31).round - old_fee_covers_current_period, (2000 * 10 / 31).round])
            expect(invoice.fees.fixed_charge.sample.properties).to include(
              "fixed_charges_from_datetime" => "2025-12-22T12:12:00.000Z",
              "fixed_charges_to_datetime" => "2025-12-31T23:59:59.999Z"
            )
          end
        end
      end

      context "when fixed charges are not prorated" do
        let(:prorated) { false }

        it "calculates all fees" do
          # 2023, 7, 19, 12, 12
          travel_to(subscription_at) do
            create_subscription({
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code,
              billing_time: "calendar"
            })
          end
          subscription = customer.subscriptions.first
          expect(subscription).to be_active
          expect(subscription.invoices.count).to eq(1)
          invoice = subscription.invoices.first
          expect(invoice.fees.fixed_charge.count).to eq(2)
          # charges are not prorated
          expect(invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([1000, 1500])
          expect(invoice.fees.fixed_charge.sample.properties).to include(
            "fixed_charges_from_datetime" => "2023-07-19T12:12:00.000Z",
            "fixed_charges_to_datetime" => "2023-07-31T23:59:59.999Z"
          )
          travel_to(DateTime.new(2023, 8, 1, 0, 0)) do
            expect { perform_billing }.to change { subscription.reload.invoices.count }.from(1).to(2)
          end

          invoice = subscription.invoices.order(created_at: :asc).last
          expect(invoice.fees.fixed_charge.count).to eq(2)
          # charges are not prorated
          expect(invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([1000, 1500])
          expect(invoice.fees.fixed_charge.sample.properties).to include(
            "fixed_charges_from_datetime" => "2023-08-01T00:00:00.000Z",
            "fixed_charges_to_datetime" => "2023-08-31T23:59:59.999Z"
          )

          travel_to(DateTime.new(2023, 8, 21, 12, 0, 0)) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan_upgrade.code,
                billing_time: "calendar"
              }
            )

            expect(subscription.reload).to be_terminated
            new_subscription = subscription.reload.next_subscription
            expect(subscription.invoices.count).to eq(3)
            # it creates only subscription invoice for the old plan and fees for the new plan
            invoice = subscription.invoices.order(:created_at).last
            expect(invoice.invoice_subscriptions.count).to eq(2)
            expect(invoice.invoice_subscriptions.map(&:subscription)).to match_array([subscription, new_subscription])
            expect(invoice.fees.subscription.count).to eq(1)
            expect(invoice.fees.subscription.map(&:amount_cents)).to match_array([(100 * 20 / 31.0).round])
            # this invoice include full fixed charges for the new plan
            expect(invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([10000, 2000])
            expect(invoice.fees.fixed_charge.sample.properties).to include(
              "fixed_charges_from_datetime" => "2023-08-21T12:00:00.000Z",
              "fixed_charges_to_datetime" => "2023-08-31T23:59:59.999Z"
            )
          end
          new_subscription = subscription.reload.next_subscription
          expect(new_subscription).to be_active
          expect(new_subscription.invoices.count).to be(1)

          travel_to(DateTime.new(2023, 9, 1, 0, 0)) do
            # Now we do charge the new month for the new subscription (paid in advance)
            expect { perform_billing }.to change { new_subscription.reload.invoices.count }.from(1).to(2)
            new_sub_invoice = new_subscription.invoices.order(created_at: :asc).last
            expect(new_sub_invoice.fees.fixed_charge.count).to eq(2)
            expect(new_sub_invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([10000, 2000])
            expect(new_sub_invoice.fees.fixed_charge.sample.properties).to include(
              "fixed_charges_from_datetime" => "2023-09-01T00:00:00.000Z",
              "fixed_charges_to_datetime" => "2023-09-30T23:59:59.999Z"
            )
          end
        end
      end
    end

    context "when fixed charges are in_arrears" do
      let(:pay_in_advance) { false }

      context "when fixed charges are prorated" do
        let(:prorated) { true }

        it "calculates all fees" do
          # 2023, 7, 19, 12, 12
          travel_to(subscription_at) do
            create_subscription({
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code,
              billing_time: "calendar"
            })
          end
          subscription = customer.subscriptions.first
          expect(subscription).to be_active
          expect(subscription.invoices.count).to eq(0)
          travel_to(DateTime.new(2023, 8, 1, 0, 0)) do
            expect { perform_billing }.to change { subscription.reload.invoices.count }.from(0).to(1)
          end

          invoice = subscription.invoices.order(created_at: :asc).last
          expect(invoice.fees.fixed_charge.count).to eq(2)
          expect(invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([1000 * 13 / 31, 1500 * 13 / 31])
          expect(invoice.fees.fixed_charge.sample.properties).to include(
            "fixed_charges_from_datetime" => "2023-07-19T12:12:00.000Z",
            "fixed_charges_to_datetime" => "2023-07-31T23:59:59.999Z"
          )

          travel_to(DateTime.new(2023, 8, 21, 12, 0, 0)) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan_upgrade.code,
                billing_time: "calendar"
              }
            )

            expect(subscription.reload).to be_terminated
            expect(subscription.invoices.count).to eq(2)
            # it creates fees for pay in arrears prorated charges
            termination_invoice = subscription.invoices.order(:created_at).last
            # the charges were active 21 days out of 31, because upgrade happened on 21st...
            expect(termination_invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([1000 * 21 / 31, 1500 * 21 / 31])
            expect(termination_invoice.fees.fixed_charge.sample.properties).to include(
              "fixed_charges_from_datetime" => "2023-08-01T00:00:00.000Z",
              "fixed_charges_to_datetime" => "2023-08-21T12:00:00.000Z"
            )
          end
          new_subscription = subscription.reload.next_subscription
          expect(new_subscription).to be_active
          expect(new_subscription.invoices.count).to be(0)

          travel_to(DateTime.new(2023, 9, 1, 0, 0)) do
            # Now we do charge the rest of the month for the new subscription
            expect { perform_billing }.to change { new_subscription.reload.invoices.count }.from(0).to(1)
            new_sub_invoice = new_subscription.invoices.first
            expect(new_sub_invoice.fees.fixed_charge.count).to eq(2)
            expect(new_sub_invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([10000 * 11 / 31, (2000 * 11 / 31.0).round])
            expect(new_sub_invoice.fees.fixed_charge.sample.properties).to include(
              "fixed_charges_from_datetime" => "2023-08-21T12:00:00.000Z",
              "fixed_charges_to_datetime" => "2023-08-31T23:59:59.999Z"
            )
          end

          travel_to(DateTime.new(2023, 10, 1, 0, 0)) do
            # finally charge the full subscription
            expect { perform_billing }.to change { new_subscription.reload.invoices.count }.from(1).to(2)
          end
          invoice = new_subscription.invoices.order(created_at: :asc).last
          expect(invoice.fees.fixed_charge.count).to eq(2)
          expect(invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([10000, 2000])
          expect(invoice.fees.fixed_charge.sample.properties).to include(
            "fixed_charges_from_datetime" => "2023-09-01T00:00:00.000Z",
            "fixed_charges_to_datetime" => "2023-09-30T23:59:59.999Z"
          )
        end
      end

      context "when fixed charges are not prorated" do
        let(:prorated) { false }

        it "calculates all fees" do
          # 2023, 7, 19, 12, 12
          travel_to(subscription_at) do
            create_subscription({
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code,
              billing_time: "calendar"
            })
          end
          subscription = customer.subscriptions.first
          expect(subscription).to be_active
          expect(subscription.invoices.count).to eq(0)
          travel_to(DateTime.new(2023, 8, 1, 0, 0)) do
            expect { perform_billing }.to change { subscription.reload.invoices.count }.from(0).to(1)
          end

          invoice = subscription.invoices.order(created_at: :asc).last
          expect(invoice.fees.fixed_charge.count).to eq(2)
          expect(invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([1000, 1500])
          expect(invoice.fees.fixed_charge.sample.properties).to include(
            "fixed_charges_from_datetime" => "2023-07-19T12:12:00.000Z",
            "fixed_charges_to_datetime" => "2023-07-31T23:59:59.999Z"
          )

          travel_to(DateTime.new(2023, 8, 21, 12, 0, 0)) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan_upgrade.code,
                billing_time: "calendar"
              }
            )

            expect(subscription.reload).to be_terminated
            expect(subscription.invoices.count).to eq(2)
            # it creates fees for pay in arrears full charges
            termination_invoice = subscription.invoices.order(:created_at).last
            expect(termination_invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([1000, 1500])
            expect(termination_invoice.fees.fixed_charge.sample.properties).to include(
              "fixed_charges_from_datetime" => "2023-08-01T00:00:00.000Z",
              "fixed_charges_to_datetime" => "2023-08-21T12:00:00.000Z"
            )
          end
          new_subscription = subscription.reload.next_subscription
          expect(new_subscription).to be_active
          expect(new_subscription.invoices.count).to be(0)

          travel_to(DateTime.new(2023, 9, 1, 0, 0)) do
            # pay in arrears full charges for the end of the month when it was prorated
            expect { perform_billing }.to change { new_subscription.reload.invoices.count }.from(0).to(1)
            new_sub_invoice = new_subscription.invoices.first
            expect(new_sub_invoice.fees.fixed_charge.count).to eq(2)
            expect(new_sub_invoice.fees.fixed_charge.map(&:amount_cents)).to match_array([10000, 2000])
            expect(new_sub_invoice.fees.fixed_charge.sample.properties).to include(
              "fixed_charges_from_datetime" => "2023-08-21T12:00:00.000Z",
              "fixed_charges_to_datetime" => "2023-08-31T23:59:59.999Z"
            )
          end
        end
      end
    end
  end
end
