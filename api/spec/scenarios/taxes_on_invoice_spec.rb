# frozen_string_literal: true

require "rails_helper"

describe "Taxes on Invoice Scenarios", :premium do
  let(:organization) { create(:organization, webhook_url: nil) }

  before do
    stub_pdf_generation
    organization
  end

  context "when timezone is negative and not the same day as UTC" do
    it "creates an invoice for the expected period" do
      travel_to(DateTime.new(2023, 1, 1)) do
        create_tax({name: "Banking rates", code: "banking_rates", rate: 10.0})
        create_tax({name: "Sales tax - FR", code: "sales_tax_fr", rate: 0.0})
        create_tax({name: "Sales tax", code: "sales_tax", rate: 20.0})

        create_or_update_customer({external_id: "customer-1"})

        create_metric({name: "FX Transfers", code: "fx_transfers", aggregation_type: "sum_agg", field_name: "total"})
        fx_transfers = organization.billable_metrics.find_by(code: "fx_transfers")
        create_metric({name: "Cards", code: "cards", aggregation_type: "count_agg"})
        cards = organization.billable_metrics.find_by(code: "cards")

        create_plan(
          {
            name: "P1",
            code: "plan_code",
            interval: "monthly",
            amount_cents: 10_000,
            amount_currency: "EUR",
            pay_in_advance: false,
            tax_codes: ["banking_rates"],
            charges: [
              {
                billable_metric_id: fx_transfers.id,
                charge_model: "standard",
                properties: {amount: "1"},
                tax_codes: [organization.taxes.find_by(code: "sales_tax_fr").code]
              },
              {
                billable_metric_id: cards.id,
                charge_model: "standard",
                min_amount_cents: 5000,
                properties: {amount: "30"},
                tax_codes: [organization.taxes.find_by(code: "sales_tax").code]
              }
            ]
          }
        )
        plan = organization.plans.find_by(code: "plan_code")

        create_subscription(
          {
            external_customer_id: "customer-1",
            external_id: "sub_external_id",
            plan_code: plan.code
          }
        )

        create_coupon(
          {
            name: "coupon1",
            code: "coupon1_code",
            coupon_type: "fixed_amount",
            frequency: "once",
            amount_cents: 1000,
            amount_currency: "EUR",
            expiration: "time_limit",
            expiration_at: Time.current + 15.days,
            reusable: false
          }
        )
        apply_coupon({external_customer_id: "customer-1", coupon_code: "coupon1_code"})

        create_event(
          {
            code: fx_transfers.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: "sub_external_id",
            properties: {total: 50}
          }
        )

        create_event(
          {
            code: cards.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: "sub_external_id"
          }
        )
      end

      travel_to(DateTime.new(2023, 2, 1)) do
        perform_billing
      end

      customer = organization.customers.find_by(external_id: "customer-1")
      invoice = customer.invoices.first
      fees = invoice.fees

      expect(invoice.fees.count).to eq(4)

      # Subscription fee
      expect(fees.subscription.first).to have_attributes(
        amount_cents: 10_000,
        taxes_amount_cents: 950,
        taxes_rate: 10.0,
        # fee amount cents * coupon amount / total fees amount (100 * 10 / 200)
        precise_coupons_amount_cents: 500
      )

      fx_transfers = organization.billable_metrics.find_by(code: "fx_transfers")
      cards = organization.billable_metrics.find_by(code: "cards")

      # FX Transfers fee
      fx_transfers_fee = fees.charge.find_by(charge: fx_transfers.charges.first)
      expect(fx_transfers_fee).to have_attributes(
        amount_cents: 5000,
        taxes_amount_cents: 0,
        taxes_rate: 0.0,
        precise_coupons_amount_cents: 250, # 50 * 10 / 200
        events_count: 1,
        units: 50
      )

      # Cards fee
      cards_fee = fees.charge.where(true_up_parent_fee_id: nil).find_by(charge: cards.charges.first)
      expect(cards_fee).to have_attributes(
        amount_cents: 3000,
        taxes_amount_cents: 570,
        taxes_rate: 20.0,
        precise_coupons_amount_cents: 150, # 30 * 10 / 200
        events_count: 1,
        units: 1
      )

      # True up - Cards fee
      true_up_cards_fee = fees.charge.where.not(true_up_parent_fee_id: nil).find_by(charge: cards.charges.first)
      expect(true_up_cards_fee).to have_attributes(
        amount_cents: 2000,
        taxes_amount_cents: 380,
        taxes_rate: 20.0,
        precise_coupons_amount_cents: 100, # 20 * 10 / 200
        events_count: 0,
        units: 1
      )

      expect(invoice).to have_attributes(
        fees_amount_cents: 20_000,
        coupons_amount_cents: 1000,
        taxes_amount_cents: 1900,
        sub_total_excluding_taxes_amount_cents: 19_000,
        sub_total_including_taxes_amount_cents: 20_900,
        total_amount_cents: 20_900
      )
    end
  end

  context "when coupons amount is greater than fees total amount" do
    it "creates an invoice for the expected period" do
      travel_to(DateTime.new(2023, 1, 1)) do
        create_tax({name: "Banking rates", code: "banking_rates", rate: 10.0})

        create_or_update_customer({external_id: "customer-1"})

        create_plan(
          {
            name: "P1",
            code: "plan_code",
            interval: "monthly",
            amount_cents: 10_000,
            amount_currency: "EUR",
            pay_in_advance: false,
            tax_codes: ["banking_rates"],
            charges: []
          }
        )
        plan = organization.plans.find_by(code: "plan_code")

        create_subscription(
          {
            external_customer_id: "customer-1",
            external_id: "sub_external_id",
            plan_code: plan.code
          }
        )

        create_coupon(
          {
            name: "coupon1",
            code: "coupon1_code",
            coupon_type: "fixed_amount",
            frequency: "once",
            amount_cents: 1000,
            amount_currency: "EUR",
            expiration: "time_limit",
            expiration_at: Time.current + 15.days,
            reusable: false
          }
        )
        apply_coupon({external_customer_id: "customer-1", coupon_code: "coupon1_code"})

        create_coupon(
          {
            name: "coupon2",
            code: "coupon2_code",
            coupon_type: "fixed_amount",
            frequency: "once",
            amount_cents: 11_000,
            amount_currency: "EUR",
            expiration: "time_limit",
            expiration_at: Time.current + 15.days,
            reusable: false
          }
        )
        apply_coupon({external_customer_id: "customer-1", coupon_code: "coupon2_code"})
      end

      travel_to(DateTime.new(2023, 2, 1)) do
        perform_billing
      end

      customer = organization.customers.find_by(external_id: "customer-1")
      invoice = customer.invoices.first
      fees = invoice.fees

      expect(invoice.fees.count).to eq(1)

      # Subscription fee
      expect(fees.subscription.first).to have_attributes(
        amount_cents: 10_000,
        taxes_amount_cents: 0,
        taxes_rate: 10.0,
        # fee amount cents * coupon amount / total fees amount (100 * 10 / 100)
        precise_coupons_amount_cents: 10_000
      )
    end
  end

  context "when there are multiple subscriptions and coupons are covering total amount" do
    it "creates an invoice for the expected period" do
      travel_to(DateTime.new(2023, 1, 1)) do
        create_tax({name: "Banking rates", code: "banking_rates", rate: 10.0})

        create_or_update_customer({external_id: "customer-1"})

        create_plan(
          {
            name: "P1",
            code: "plan_code",
            interval: "monthly",
            amount_cents: 10_000,
            amount_currency: "EUR",
            pay_in_advance: false,
            tax_codes: ["banking_rates"],
            charges: []
          }
        )
        plan = organization.plans.find_by(code: "plan_code")

        create_subscription(
          {
            external_customer_id: "customer-1",
            external_id: "sub_external_id",
            plan_code: plan.code
          }
        )

        create_plan(
          {
            name: "P2",
            code: "plan_code2",
            interval: "monthly",
            amount_cents: 5_000,
            amount_currency: "EUR",
            pay_in_advance: false,
            tax_codes: ["banking_rates"],
            charges: []
          }
        )
        plan2 = organization.plans.find_by(code: "plan_code2")

        create_subscription(
          {
            external_customer_id: "customer-1",
            external_id: "sub_external_id2",
            plan_code: plan2.code
          }
        )

        create_coupon(
          {
            name: "coupon1",
            code: "coupon1_code",
            coupon_type: "fixed_amount",
            frequency: "once",
            amount_cents: 10_000,
            amount_currency: "EUR",
            expiration: "time_limit",
            expiration_at: Time.current + 15.days,
            reusable: false
          }
        )
        apply_coupon({external_customer_id: "customer-1", coupon_code: "coupon1_code"})

        create_coupon(
          {
            name: "coupon2",
            code: "coupon2_code",
            coupon_type: "fixed_amount",
            frequency: "once",
            amount_cents: 10_000,
            amount_currency: "EUR",
            expiration: "time_limit",
            expiration_at: Time.current + 15.days,
            reusable: false
          }
        )
        apply_coupon({external_customer_id: "customer-1", coupon_code: "coupon2_code"})
      end

      travel_to(DateTime.new(2023, 2, 1)) do
        perform_billing
      end

      customer = organization.customers.find_by(external_id: "customer-1")
      invoice = customer.invoices.first
      fees = invoice.fees
      subscription1 = Subscription.find_by(external_id: "sub_external_id")
      subscription2 = Subscription.find_by(external_id: "sub_external_id2")

      expect(invoice.fees.count).to eq(2)

      # Subscription fee1
      expect(fees.subscription.where(subscription: subscription1).first).to have_attributes(
        amount_cents: 10_000,
        taxes_amount_cents: 0,
        taxes_rate: 10.0,
        # fee amount cents * coupon amount / total fees amount (100 * 10 / 100)
        precise_coupons_amount_cents: 10_000
      )

      # Subscription fee2
      expect(fees.subscription.where(subscription: subscription2).first).to have_attributes(
        amount_cents: 5_000,
        taxes_amount_cents: 0,
        taxes_rate: 10.0,
        # fee amount cents * coupon amount / total fees amount (50 * 5 / 50)
        precise_coupons_amount_cents: 5_000
      )
    end
  end
end
