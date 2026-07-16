# frozen_string_literal: true

require "rails_helper"

describe "Billing Boundaries Scenario" do
  let(:organization) { create(:organization, webhook_url: nil) }

  let(:timezone) { "UTC" }
  let(:customer) { create(:customer, organization:, timezone:) }

  let(:plan_interval) { :monthly }
  let(:plan_monthly_charges) { false }
  let(:plan_monthly_fixed_charges) { false }
  let(:plan_in_advance) { false }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:charge) { create(:standard_charge, plan:, billable_metric:) }
  let(:add_on) { create(:add_on, organization:) }
  let(:fixed_charge) { create(:fixed_charge, plan:, add_on:) }

  let(:billing_time) { "anniversary" }

  let(:plan) do
    create(
      :plan,
      organization:,
      interval: plan_interval,
      pay_in_advance: plan_in_advance,
      bill_charges_monthly: plan_monthly_charges,
      bill_fixed_charges_monthly: plan_monthly_fixed_charges
    )
  end

  before do
    charge
    fixed_charge
  end

  it "creates invoices" do
    travel_to(Time.zone.parse("2024-01-31T01:00:00Z")) do
      create_subscription(
        {external_customer_id: customer.external_id,
         external_id: customer.external_id,
         plan_code: plan.code,
         billing_time:}
      )
    end

    subscription = customer.subscriptions.first

    # February billing
    travel_to(Time.zone.parse("2024-02-29T02:00:00Z")) do
      expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
    end

    invoice = subscription.invoices.order(created_at: :desc).first
    invoice_subscription = invoice.invoice_subscriptions.first

    expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
    expect(invoice_subscription.to_datetime).to match_datetime("2024-02-28T23:59:59Z")
    expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
    expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-02-28T23:59:59Z")
    expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
    expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-02-28T23:59:59Z")

    # March billing
    travel_to(Time.zone.parse("2024-03-31T02:00:00Z")) do
      expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
    end

    invoice = subscription.invoices.order(created_at: :desc).first
    invoice_subscription = invoice.invoice_subscriptions.first

    expect(invoice_subscription.from_datetime).to match_datetime("2024-02-29T00:00:00Z")
    expect(invoice_subscription.to_datetime).to match_datetime("2024-03-30T23:59:59Z")
    expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-02-29T00:00:00Z")
    expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-03-30T23:59:59Z")
    expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-02-29T00:00:00Z")
    expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-03-30T23:59:59Z")

    # April billing
    travel_to(Time.zone.parse("2024-04-30T02:00:00Z")) do
      expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
    end

    invoice = subscription.invoices.order(created_at: :desc).first
    invoice_subscription = invoice.invoice_subscriptions.first

    expect(invoice_subscription.from_datetime).to match_datetime("2024-03-31T00:00:00Z")
    expect(invoice_subscription.to_datetime).to match_datetime("2024-04-29T23:59:59Z")
    expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-03-31T00:00:00Z")
    expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-04-29T23:59:59Z")
    expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-03-31T00:00:00Z")
    expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-04-29T23:59:59Z")
  end

  context "with plans in advance and all charges are in arrears" do
    let(:plan_in_advance) { true }

    it "creates invoices" do
      travel_to(Time.zone.parse("2024-01-30T00:00:00Z")) do
        create_subscription(
          {external_customer_id: customer.external_id,
           external_id: customer.external_id,
           plan_code: plan.code,
           billing_time:}
        )
      end

      subscription = customer.subscriptions.first
      expect(subscription.invoices.count).to eq(1)

      invoice = subscription.invoices.order(created_at: :desc).first
      invoice_subscription = invoice.invoice_subscriptions.first

      expect(invoice_subscription.from_datetime).to match_datetime("2024-01-30T00:00:00Z")
      expect(invoice_subscription.to_datetime).to match_datetime("2024-02-28T23:59:59Z")

      # February billing
      travel_to(Time.zone.parse("2024-02-29T02:00:00Z")) do
        expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
      end

      invoice = subscription.invoices.order(created_at: :desc).first
      invoice_subscription = invoice.invoice_subscriptions.first

      expect(invoice_subscription.from_datetime).to match_datetime("2024-02-29T00:00:00Z")
      expect(invoice_subscription.to_datetime).to match_datetime("2024-03-29T23:59:59Z")
      expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-30T00:00:00Z")
      expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-02-28T23:59:59Z")
      expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-30T00:00:00Z")
      expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-02-28T23:59:59Z")

      # March billing
      travel_to(Time.zone.parse("2024-03-30T02:00:00Z")) do
        expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
      end

      invoice = subscription.invoices.order(created_at: :desc).first
      invoice_subscription = invoice.invoice_subscriptions.first

      expect(invoice_subscription.from_datetime).to match_datetime("2024-03-30T00:00:00Z")
      expect(invoice_subscription.to_datetime).to match_datetime("2024-04-29T23:59:59Z")
      expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-02-29T00:00:00Z")
      expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-03-29T23:59:59Z")
      expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-02-29T00:00:00Z")
      expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-03-29T23:59:59Z")

      # April billing
      travel_to(Time.zone.parse("2024-04-30T02:00:00Z")) do
        expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
      end

      invoice = subscription.invoices.order(created_at: :desc).first
      invoice_subscription = invoice.invoice_subscriptions.first

      expect(invoice_subscription.from_datetime).to match_datetime("2024-04-30T00:00:00Z")
      expect(invoice_subscription.to_datetime).to match_datetime("2024-05-29T23:59:59Z")
      expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-03-30T00:00:00Z")
      expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-04-29T23:59:59Z")
      expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-03-30T00:00:00Z")
      expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-04-29T23:59:59Z")
    end
  end

  context "when interval is yearly" do
    let(:plan_interval) { :yearly }

    it "creates invoices once a year" do
      travel_to(Time.zone.parse("2024-01-31T01:00:00Z")) do
        create_subscription(
          {external_customer_id: customer.external_id,
           external_id: customer.external_id,
           plan_code: plan.code,
           billing_time:}
        )
      end

      subscription = customer.subscriptions.first

      # February billing
      travel_to(Time.zone.parse("2024-02-29T02:00:00Z")) do
        expect { perform_billing }.not_to change { subscription.reload.invoices.count }
      end

      # March billing
      travel_to(Time.zone.parse("2024-03-31T02:00:00Z")) do
        expect { perform_billing }.not_to change { subscription.reload.invoices.count }
      end

      # April billing
      travel_to(Time.zone.parse("2024-04-30T02:00:00Z")) do
        expect { perform_billing }.not_to change { subscription.reload.invoices.count }
      end

      # next year billing
      travel_to(Time.zone.parse("2025-01-31T02:00:00Z")) do
        expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
      end

      invoice = subscription.invoices.order(created_at: :desc).first
      invoice_subscription = invoice.invoice_subscriptions.first

      expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
      expect(invoice_subscription.to_datetime).to match_datetime("2025-01-30T23:59:59Z")
      expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
      expect(invoice_subscription.charges_to_datetime).to match_datetime("2025-01-30T23:59:59Z")
      expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
      expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2025-01-30T23:59:59Z")
    end

    context "when charges are billed monthly" do
      let(:plan_monthly_charges) { true }

      it "creates invoices" do
        travel_to(Time.zone.parse("2024-01-31T01:00:00Z")) do
          create_subscription(
            {external_customer_id: customer.external_id,
             external_id: customer.external_id,
             plan_code: plan.code,
             billing_time:}
          )
        end

        subscription = customer.subscriptions.first

        travel_to(Time.zone.parse("2024-02-01T00:00:00Z")) do
          create_event(
            {
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              code: billable_metric.code,
              properties: {
                billable_metric.field_name => 10
              }
            }
          )
        end

        # February billing
        travel_to(Time.zone.parse("2024-02-29T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-02-28T23:59:59Z")
        # when only charges are billed monthly, fixed charge boundaries are nil
        expect(invoice_subscription.fixed_charges_from_datetime).to eq(nil)
        expect(invoice_subscription.fixed_charges_to_datetime).to eq(nil)

        # March billing
        travel_to(Time.zone.parse("2024-03-31T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-02-29T00:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-03-30T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to eq(nil)
        expect(invoice_subscription.fixed_charges_to_datetime).to eq(nil)

        # April billing
        travel_to(Time.zone.parse("2024-04-30T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-03-31T00:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-04-29T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to eq(nil)
        expect(invoice_subscription.fixed_charges_to_datetime).to eq(nil)

        # next year billing
        travel_to(Time.zone.parse("2025-01-31T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2025-01-30T23:59:59Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-12-31T00:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2025-01-30T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2025-01-30T23:59:59Z")
      end
    end

    context "when fixed charges are billed monthly" do
      let(:plan_monthly_fixed_charges) { true }

      it "creates invoices" do
        travel_to(Time.zone.parse("2024-01-31T01:00:00Z")) do
          create_subscription(
            {external_customer_id: customer.external_id,
             external_id: customer.external_id,
             plan_code: plan.code,
             billing_time:}
          )
        end

        subscription = customer.subscriptions.first

        travel_to(Time.zone.parse("2024-02-01T00:00:00Z")) do
          create_event(
            {
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              code: billable_metric.code,
              properties: {
                billable_metric.field_name => 10
              }
            }
          )
        end

        # February billing
        travel_to(Time.zone.parse("2024-02-29T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_from_datetime).to eq(nil)
        expect(invoice_subscription.charges_to_datetime).to eq(nil)
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-02-28T23:59:59Z")

        # March billing
        travel_to(Time.zone.parse("2024-03-31T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_from_datetime).to eq(nil)
        expect(invoice_subscription.charges_to_datetime).to eq(nil)
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-02-29T00:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-03-30T23:59:59Z")

        # April billing
        travel_to(Time.zone.parse("2024-04-30T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_from_datetime).to eq(nil)
        expect(invoice_subscription.charges_to_datetime).to eq(nil)
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-03-31T00:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-04-29T23:59:59Z")

        # next year billing
        travel_to(Time.zone.parse("2025-01-31T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2025-01-30T23:59:59Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2025-01-30T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-12-31T00:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2025-01-30T23:59:59Z")
      end
    end

    context "when both charges and fixed charges are billed monthly" do
      let(:plan_monthly_charges) { true }
      let(:plan_monthly_fixed_charges) { true }

      it "creates invoices" do
        travel_to(Time.zone.parse("2024-01-31T01:00:00Z")) do
          create_subscription(
            {external_customer_id: customer.external_id,
             external_id: customer.external_id,
             plan_code: plan.code,
             billing_time:}
          )
        end

        subscription = customer.subscriptions.first

        travel_to(Time.zone.parse("2024-02-01T00:00:00Z")) do
          create_event(
            {
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              code: billable_metric.code,
              properties: {
                billable_metric.field_name => 10
              }
            }
          )
        end

        # February billing
        travel_to(Time.zone.parse("2024-02-29T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-02-28T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-02-28T23:59:59Z")

        # March billing
        travel_to(Time.zone.parse("2024-03-31T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-02-29T00:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-03-30T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-02-29T00:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-03-30T23:59:59Z")

        # next year billing
        travel_to(Time.zone.parse("2025-01-31T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2025-01-30T23:59:59Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-12-31T00:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2025-01-30T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-12-31T00:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2025-01-30T23:59:59Z")
      end
    end

    context "when plan is in advance and charges are billed monthly" do
      let(:plan_in_advance) { true }
      let(:plan_monthly_charges) { true }

      it "creates invoices" do
        travel_to(Time.zone.parse("2024-01-31T01:00:00Z")) do
          create_subscription(
            {external_customer_id: customer.external_id,
             external_id: customer.external_id,
             plan_code: plan.code,
             billing_time:}
          )
        end

        subscription = customer.subscriptions.first
        expect(subscription.invoices.count).to eq(1)

        # First invoice - subscription creation (pay in advance)
        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2025-01-30T23:59:59Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-01-31T01:00:00Z")

        travel_to(Time.zone.parse("2024-02-01T00:00:00Z")) do
          create_event(
            {
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              code: billable_metric.code,
              properties: {
                billable_metric.field_name => 10
              }
            }
          )
        end

        # February billing - second invoice (charges only)
        travel_to(Time.zone.parse("2024-02-29T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2025-01-30T23:59:59Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-02-28T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to eq(nil)
        expect(invoice_subscription.fixed_charges_to_datetime).to eq(nil)

        # next year billing
        travel_to(Time.zone.parse("2025-01-31T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2025-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2026-01-30T23:59:59Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-12-31T00:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2025-01-30T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2025-01-30T23:59:59Z")
      end
    end

    context "when plan is in advance and fixed charges are billed monthly" do
      let(:plan_in_advance) { true }
      let(:plan_monthly_fixed_charges) { true }

      it "creates invoices" do
        travel_to(Time.zone.parse("2024-01-31T01:00:00Z")) do
          create_subscription(
            {external_customer_id: customer.external_id,
             external_id: customer.external_id,
             plan_code: plan.code,
             billing_time:}
          )
        end

        subscription = customer.subscriptions.first
        expect(subscription.invoices.count).to eq(1)

        # First invoice - subscription creation (pay in advance)
        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2025-01-30T23:59:59Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-01-31T01:00:00Z")

        # February billing - second invoice (fixed charges only)
        travel_to(Time.zone.parse("2024-02-29T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2025-01-30T23:59:59Z")
        expect(invoice_subscription.charges_from_datetime).to eq(nil)
        expect(invoice_subscription.charges_to_datetime).to eq(nil)
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-02-28T23:59:59Z")

        # next year billing
        travel_to(Time.zone.parse("2025-01-31T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2025-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2026-01-30T23:59:59Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2025-01-30T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-12-31T00:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2025-01-30T23:59:59Z")
      end
    end
  end

  context "when interval is semiannual" do
    let(:plan_interval) { :semiannual }

    it "creates invoices twice a year" do
      travel_to(Time.zone.parse("2024-01-31T01:00:00Z")) do
        create_subscription(
          {external_customer_id: customer.external_id,
           external_id: customer.external_id,
           plan_code: plan.code,
           billing_time:}
        )
      end

      subscription = customer.subscriptions.first

      # February billing
      travel_to(Time.zone.parse("2024-02-29T02:00:00Z")) do
        expect { perform_billing }.not_to change { subscription.reload.invoices.count }
      end

      # March billing
      travel_to(Time.zone.parse("2024-03-31T02:00:00Z")) do
        expect { perform_billing }.not_to change { subscription.reload.invoices.count }
      end

      # April billing
      travel_to(Time.zone.parse("2024-04-30T02:00:00Z")) do
        expect { perform_billing }.not_to change { subscription.reload.invoices.count }
      end

      # May billing
      travel_to(Time.zone.parse("2024-05-31T02:00:00Z")) do
        expect { perform_billing }.not_to change { subscription.reload.invoices.count }
      end

      # June billing
      travel_to(Time.zone.parse("2024-06-30T02:00:00Z")) do
        expect { perform_billing }.not_to change { subscription.reload.invoices.count }
      end

      # July billing
      travel_to(Time.zone.parse("2024-07-31T02:00:00Z")) do
        expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
      end

      invoice = subscription.invoices.order(created_at: :desc).first
      invoice_subscription = invoice.invoice_subscriptions.first

      expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
      expect(invoice_subscription.to_datetime).to match_datetime("2024-07-30T23:59:59Z")
      expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
      expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-07-30T23:59:59Z")
      expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
      expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-07-30T23:59:59Z")

      # August billing
      travel_to(Time.zone.parse("2024-08-30T02:00:00Z")) do
        expect { perform_billing }.not_to change { subscription.reload.invoices.count }
      end

      # Next year Jan billing
      travel_to(Time.zone.parse("2025-01-31T02:00:00Z")) do
        expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
      end

      invoice = subscription.invoices.order(created_at: :desc).first
      invoice_subscription = invoice.invoice_subscriptions.first

      expect(invoice_subscription.from_datetime).to match_datetime("2024-07-31T00:00:00Z")
      expect(invoice_subscription.to_datetime).to match_datetime("2025-01-30T23:59:59Z")
      expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-07-31T00:00:00Z")
      expect(invoice_subscription.charges_to_datetime).to match_datetime("2025-01-30T23:59:59Z")
      expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-07-31T00:00:00Z")
      expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2025-01-30T23:59:59Z")
    end

    context "when charges are billed monthly" do
      let(:plan_monthly_charges) { true }

      it "creates invoices" do
        travel_to(Time.zone.parse("2024-01-31T01:00:00Z")) do
          create_subscription(
            {external_customer_id: customer.external_id,
             external_id: customer.external_id,
             plan_code: plan.code,
             billing_time:}
          )
        end

        subscription = customer.subscriptions.first

        travel_to(Time.zone.parse("2024-02-01T00:00:00Z")) do
          create_event(
            {
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              code: billable_metric.code,
              properties: {
                billable_metric.field_name => 10
              }
            }
          )
        end

        # February billing
        travel_to(Time.zone.parse("2024-02-29T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        # TODO: only in semiannual these dates are not following the behaviour where previous billing period is provided.
        # expect(invoice_subscription.to_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-02-28T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to eq(nil)
        # TODO: only in semiannual these dates are not following the behaviour where previous billing period is provided.
        # expect(invoice_subscription.fixed_charges_to_datetime).to eq(nil)

        # March billing
        travel_to(Time.zone.parse("2024-03-31T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        # TODO: only in semiannual these dates are not following the behaviour where previous billing period is provided.
        # expect(invoice_subscription.to_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-02-29T00:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-03-30T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to eq(nil)
        # TODO: only in semiannual these dates are not following the behaviour where previous billing period is provided.
        # expect(invoice_subscription.fixed_charges_to_datetime).to eq(nil)

        # July billing
        travel_to(Time.zone.parse("2024-07-31T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2024-07-30T23:59:59Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-06-30T00:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-07-30T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-07-30T23:59:59Z")
      end
    end

    context "when fixed charges are billed monthly" do
      let(:plan_monthly_fixed_charges) { true }

      it "creates invoices" do
        travel_to(Time.zone.parse("2024-01-31T01:00:00Z")) do
          create_subscription(
            {external_customer_id: customer.external_id,
             external_id: customer.external_id,
             plan_code: plan.code,
             billing_time:}
          )
        end

        subscription = customer.subscriptions.first

        # February billing
        travel_to(Time.zone.parse("2024-02-29T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.charges_from_datetime).to eq(nil)
        expect(invoice_subscription.charges_to_datetime).to eq(nil)
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-02-28T23:59:59Z")

        # March billing
        travel_to(Time.zone.parse("2024-03-31T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.charges_from_datetime).to eq(nil)
        expect(invoice_subscription.charges_to_datetime).to eq(nil)
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-02-29T00:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-03-30T23:59:59Z")

        # July billing
        travel_to(Time.zone.parse("2024-07-31T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2024-07-30T23:59:59Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-07-30T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-06-30T00:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-07-30T23:59:59Z")
      end
    end

    context "when both charges and fixed charges are billed monthly" do
      let(:plan_monthly_charges) { true }
      let(:plan_monthly_fixed_charges) { true }

      it "creates invoices" do
        travel_to(Time.zone.parse("2024-01-31T01:00:00Z")) do
          create_subscription(
            {external_customer_id: customer.external_id,
             external_id: customer.external_id,
             plan_code: plan.code,
             billing_time:}
          )
        end

        subscription = customer.subscriptions.first

        travel_to(Time.zone.parse("2024-02-01T00:00:00Z")) do
          create_event(
            {
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              code: billable_metric.code,
              properties: {
                billable_metric.field_name => 10
              }
            }
          )
        end

        # February billing
        travel_to(Time.zone.parse("2024-02-29T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-02-28T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-02-28T23:59:59Z")

        # March billing
        travel_to(Time.zone.parse("2024-03-31T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-02-29T00:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-03-30T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-02-29T00:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-03-30T23:59:59Z")

        # July billing
        travel_to(Time.zone.parse("2024-07-31T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2024-07-30T23:59:59Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-06-30T00:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-07-30T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-06-30T00:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-07-30T23:59:59Z")
      end
    end

    context "when plan is in advance and charges are billed monthly" do
      let(:plan_in_advance) { true }
      let(:plan_monthly_charges) { true }

      it "creates invoices" do
        travel_to(Time.zone.parse("2024-01-31T01:00:00Z")) do
          create_subscription(
            {external_customer_id: customer.external_id,
             external_id: customer.external_id,
             plan_code: plan.code,
             billing_time:}
          )
        end

        subscription = customer.subscriptions.first
        expect(subscription.invoices.count).to eq(1)

        # First invoice - subscription creation (pay in advance)
        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2024-07-30T23:59:59Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-01-31T01:00:00Z")

        travel_to(Time.zone.parse("2024-02-01T00:00:00Z")) do
          create_event(
            {
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              code: billable_metric.code,
              properties: {
                billable_metric.field_name => 10
              }
            }
          )
        end

        # February billing - second invoice (charges only)
        travel_to(Time.zone.parse("2024-02-29T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-02-29T00:00:00Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-02-28T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to eq(nil)
        expect(invoice_subscription.fixed_charges_to_datetime).to eq(nil)

        # July billing (6 months after subscription started)
        travel_to(Time.zone.parse("2024-07-31T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-07-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2025-01-30T23:59:59Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-06-30T00:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-07-30T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-07-30T23:59:59Z")
      end
    end

    context "when plan is in advance and fixed charges are billed monthly" do
      let(:plan_in_advance) { true }
      let(:plan_monthly_fixed_charges) { true }

      it "creates invoices" do
        travel_to(Time.zone.parse("2024-01-31T01:00:00Z")) do
          create_subscription(
            {external_customer_id: customer.external_id,
             external_id: customer.external_id,
             plan_code: plan.code,
             billing_time:}
          )
        end

        subscription = customer.subscriptions.first
        expect(subscription.invoices.count).to eq(1)

        # First invoice - subscription creation (pay in advance)
        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2024-07-30T23:59:59Z")

        # February billing - second invoice (fixed charges only)
        travel_to(Time.zone.parse("2024-02-29T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-02-29T00:00:00Z")
        expect(invoice_subscription.charges_from_datetime).to eq(nil)
        expect(invoice_subscription.charges_to_datetime).to eq(nil)
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-02-28T23:59:59Z")

        # July billing (6 months after subscription started)
        travel_to(Time.zone.parse("2024-07-31T02:00:00Z")) do
          expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
        end

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime).to match_datetime("2024-07-31T00:00:00Z")
        expect(invoice_subscription.to_datetime).to match_datetime("2025-01-30T23:59:59Z")
        expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
        expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-07-30T23:59:59Z")
        expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-06-30T00:00:00Z")
        expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-07-30T23:59:59Z")
      end
    end
  end

  context "when interval is quarterly" do
    let(:plan_interval) { :quarterly }

    it "creates invoices four times a year" do
      travel_to(Time.zone.parse("2024-01-31T01:00:00Z")) do
        create_subscription(
          {external_customer_id: customer.external_id,
           external_id: customer.external_id,
           plan_code: plan.code,
           billing_time:}
        )
      end

      subscription = customer.subscriptions.first

      # February billing
      travel_to(Time.zone.parse("2024-02-29T02:00:00Z")) do
        expect { perform_billing }.not_to change { subscription.reload.invoices.count }
      end

      # March billing
      travel_to(Time.zone.parse("2024-03-31T02:00:00Z")) do
        expect { perform_billing }.not_to change { subscription.reload.invoices.count }
      end

      # April billing
      travel_to(Time.zone.parse("2024-04-30T02:00:00Z")) do
        expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
      end

      invoice = subscription.invoices.order(created_at: :desc).first
      invoice_subscription = invoice.invoice_subscriptions.first

      expect(invoice_subscription.from_datetime).to match_datetime("2024-01-31T00:00:00Z")
      expect(invoice_subscription.to_datetime).to match_datetime("2024-04-29T23:59:59Z")
      expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
      expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-04-29T23:59:59Z")
      expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-31T01:00:00Z")
      expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-04-29T23:59:59Z")

      # May billing
      travel_to(Time.zone.parse("2024-05-31T02:00:00Z")) do
        expect { perform_billing }.not_to change { subscription.reload.invoices.count }
      end

      # June billing
      travel_to(Time.zone.parse("2024-06-30T02:00:00Z")) do
        expect { perform_billing }.not_to change { subscription.reload.invoices.count }
      end

      # July billing
      travel_to(Time.zone.parse("2024-07-31T02:00:00Z")) do
        expect { perform_billing }.to change { subscription.reload.invoices.count }.by(1)
      end

      invoice = subscription.invoices.order(created_at: :desc).first
      invoice_subscription = invoice.invoice_subscriptions.first

      expect(invoice_subscription.from_datetime).to match_datetime("2024-04-30T00:00:00Z")
      expect(invoice_subscription.to_datetime).to match_datetime("2024-07-30T23:59:59Z")
      expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-04-30T00:00:00Z")
      expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-07-30T23:59:59Z")
      expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-04-30T00:00:00Z")
      expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-07-30T23:59:59Z")
    end
    # NOTE: there are no quarterly with charges monthly!
  end

  context "with progressive billing thresholds", :premium, transaction: false do
    let(:organization) { create(:organization, webhook_url: nil, premium_integrations: ["progressive_billing"]) }
    let(:plan_interval) { :monthly }
    let(:billable_metric) { create(:sum_billable_metric, organization:, field_name: "amount") }
    let(:progressive_charge) do
      create(:standard_charge, plan:, billable_metric:, properties: {"amount" => "2"})
    end
    let(:usage_threshold) { create(:usage_threshold, plan:, amount_cents: 20_000) }

    before do
      progressive_charge
      usage_threshold
    end

    it "creates invoices with correct boundaries when progressive billing thresholds are crossed" do
      # Start subscription on Jan 15
      travel_to(Time.zone.parse("2024-01-15T10:00:00Z")) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            billing_time:
          }
        )
      end

      subscription = customer.subscriptions.first

      # February billing - regular billing (no progressive billing yet)
      travel_to(Time.zone.parse("2024-02-15T02:00:00Z")) do
        expect { perform_billing }.to change { subscription.reload.invoices.subscription.count }.by(1)
      end

      invoice = subscription.invoices.subscription.order(created_at: :desc).first
      invoice_subscription = invoice.invoice_subscriptions.first

      expect(invoice_subscription.from_datetime).to match_datetime("2024-01-15T00:00:00Z")
      expect(invoice_subscription.to_datetime).to match_datetime("2024-02-14T23:59:59Z")
      expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-15T10:00:00Z")
      expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-02-14T23:59:59Z")
      expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-15T10:00:00Z")
      expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-02-14T23:59:59Z")

      progressive_invoices_before = Invoice.progressive_billing.count

      # Send enough usage to cross threshold (progressive billing invoice)
      travel_to(Time.zone.parse("2024-02-20T10:00:00Z")) do
        ingest_event(subscription, billable_metric, 100)
        perform_all_enqueued_jobs
        expect(Invoice.progressive_billing.count).to eq(progressive_invoices_before + 1)
      end

      progressive_invoice = Invoice.progressive_billing.order(created_at: :desc).first
      # Progressive billing invoice should have been created
      expect(progressive_invoice.total_amount_cents).to be > 0
      progressive_invoice_subscription = progressive_invoice.invoice_subscriptions.first
      expect(progressive_invoice_subscription.from_datetime).to match_datetime("2024-02-15T00:00:00Z")
      expect(progressive_invoice_subscription.to_datetime).to match_datetime("2024-03-14T23:59:59Z")
      expect(progressive_invoice_subscription.charges_from_datetime).to match_datetime("2024-02-15T00:00:00Z")
      expect(progressive_invoice_subscription.charges_to_datetime).to match_datetime("2024-03-14T23:59:59Z")
      expect(progressive_invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-02-15T00:00:00Z")
      expect(progressive_invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-03-14T23:59:59Z")

      # March billing - end of period with progressive billing credits
      travel_to(Time.zone.parse("2024-03-15T02:00:00Z")) do
        expect { perform_billing }.to change { subscription.reload.invoices.subscription.count }.by(1)
      end

      invoice = subscription.invoices.subscription.order(created_at: :desc).first
      invoice_subscription = invoice.invoice_subscriptions.first

      expect(invoice_subscription.from_datetime).to match_datetime("2024-02-15T00:00:00Z")
      expect(invoice_subscription.to_datetime).to match_datetime("2024-03-14T23:59:59Z")
      expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-02-15T00:00:00Z")
      expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-03-14T23:59:59Z")
      expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-02-15T00:00:00Z")
      expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-03-14T23:59:59Z")

      # Verify progressive billing credits were applied (amount should match the progressive invoice)
      expect(invoice.progressive_billing_credit_amount_cents).to eq(progressive_invoice.total_amount_cents)
    end
  end

  context "with charges paid in advance" do
    let(:plan_interval) { :monthly }
    let(:billing_time) { "calendar" }

    let(:sum_billable_metric) { create(:sum_billable_metric, organization:, field_name: "amount") }
    let(:recurring_billable_metric) { create(:sum_billable_metric, :recurring, organization:, field_name: "seats") }

    # Charge combinations:
    # 1. pay_in_advance: false, recurring: false (default arrears charge)
    let(:arrears_charge) do
      create(:standard_charge, plan:, billable_metric: sum_billable_metric, properties: {amount: "1"})
    end

    # 2. pay_in_advance: true, recurring: false (advance charge, not recurring)
    let(:advance_charge) do
      create(:standard_charge, :pay_in_advance, plan:, billable_metric:, invoiceable: true, properties: {amount: "2"})
    end

    # 3. pay_in_advance: false, recurring: true (arrears recurring charge)
    let(:arrears_recurring_charge) do
      create(:standard_charge, plan:, billable_metric: recurring_billable_metric, properties: {amount: "5"})
    end

    # 4. pay_in_advance: true, recurring: true (advance recurring charge)
    let(:advance_recurring_charge) do
      create(
        :standard_charge,
        :pay_in_advance,
        plan:,
        billable_metric: recurring_billable_metric,
        invoiceable: true,
        properties: {amount: "10"}
      )
    end

    before do
      arrears_charge
      advance_charge
      arrears_recurring_charge
      advance_recurring_charge
    end

    it "creates invoices with correct boundaries for different charge types" do
      # Start subscription on Jan 1
      travel_to(Time.zone.parse("2024-01-01T10:00:00Z")) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            billing_time:
          }
        )
      end

      subscription = customer.subscriptions.first

      # Send usage for arrears charge (sum_billable_metric)
      travel_to(Time.zone.parse("2024-01-10T10:00:00Z")) do
        create_event(
          {
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            code: sum_billable_metric.code,
            properties: {sum_billable_metric.field_name => 100}
          }
        )
      end

      # Send usage for pay_in_advance charge
      travel_to(Time.zone.parse("2024-01-15T10:00:00Z")) do
        create_event(
          {
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            code: billable_metric.code,
            properties: {billable_metric.field_name => 50}
          }
        )
      end

      # Send usage for recurring billable metrics
      travel_to(Time.zone.parse("2024-01-20T10:00:00Z")) do
        create_event(
          {
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            code: recurring_billable_metric.code,
            properties: {recurring_billable_metric.field_name => 10}
          }
        )
      end

      expect(subscription.invoices.subscription.count).to eq(2) # pay in advance events

      # February billing - end of January period
      travel_to(Time.zone.parse("2024-02-01T02:00:00Z")) do
        expect { perform_billing }.to change { subscription.reload.invoices.subscription.count }.by(1)
      end

      invoice = subscription.invoices.subscription.order(created_at: :desc).first
      invoice_subscription = invoice.invoice_subscriptions.first

      # Verify boundaries are set correctly for the billing period invoice
      expect(invoice_subscription.from_datetime).to match_datetime("2024-01-01T00:00:00Z")
      expect(invoice_subscription.to_datetime).to match_datetime("2024-01-31T23:59:59Z")
      expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-01-01T10:00:00Z")
      expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-01-31T23:59:59Z")
      expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-01-01T10:00:00Z")
      expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-01-31T23:59:59Z")

      # Verify the invoice has fees for charges
      expect(invoice.fees.charge.count).to be >= 1

      # March billing - second period
      travel_to(Time.zone.parse("2024-03-01T02:00:00Z")) do
        expect { perform_billing }.to change { subscription.reload.invoices.subscription.count }.by(1)
      end

      invoice = subscription.invoices.subscription.order(created_at: :desc).first
      invoice_subscription = invoice.invoice_subscriptions.first

      expect(invoice_subscription.from_datetime).to match_datetime("2024-02-01T00:00:00Z")
      expect(invoice_subscription.to_datetime).to match_datetime("2024-02-29T23:59:59Z")
      expect(invoice_subscription.charges_from_datetime).to match_datetime("2024-02-01T00:00:00Z")
      expect(invoice_subscription.charges_to_datetime).to match_datetime("2024-02-29T23:59:59Z")
      expect(invoice_subscription.fixed_charges_from_datetime).to match_datetime("2024-02-01T00:00:00Z")
      expect(invoice_subscription.fixed_charges_to_datetime).to match_datetime("2024-02-29T23:59:59Z")
    end
  end
end
