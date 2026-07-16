# frozen_string_literal: true

require "rails_helper"

RSpec.describe "templates/invoices/v4.slim" do
  subject(:rendered_template) do
    Slim::Template.new(template, 1, pretty: true).render(invoice)
  end

  let(:template) { Rails.root.join("app/views/templates/invoices/v4.slim") }
  let(:invoice) do
    build_stubbed(
      :invoice,
      :credit,
      organization: organization,
      billing_entity: billing_entity,
      customer: customer,
      number: "LAGO-202509-001",
      payment_due_date: Date.parse("2025-09-04"),
      issuing_date: Date.parse("2025-09-04"),
      total_amount_cents: 1050,
      currency: "USD",
      fees: [fee]
    )
  end

  let(:organization) do
    build_stubbed(:organization, :with_static_values)
  end

  let(:billing_entity) do
    build_stubbed(:billing_entity, :with_static_values, organization: organization)
  end

  let(:customer) do
    build_stubbed(:customer, :with_static_values, organization: organization)
  end

  let(:wallet) do
    build_stubbed(
      :wallet,
      customer: customer,
      name: wallet_name,
      balance_currency: "USD",
      rate_amount: BigDecimal("1.0")
    )
  end

  let(:wallet_transaction) do
    build_stubbed(
      :wallet_transaction,
      wallet: wallet,
      credit_amount: BigDecimal("10.50"),
      amount: BigDecimal("10.50"),
      name: wallet_transaction_name
    )
  end
  let(:wallet_transaction_name) { nil }

  let(:fee) do
    build_stubbed(
      :fee,
      id: "87654321-0fed-cba9-8765-4321fedcba90",
      fee_type: :credit,
      invoiceable: wallet_transaction,
      amount_cents: 1050,
      amount_currency: "USD"
    )
  end

  let(:wallet_name) { "Premium Wallet" }

  before do
    I18n.locale = :en
  end

  context "when invoice_type is credit" do
    context "when wallet transaction has a name" do
      let(:wallet_transaction_name) { "Wallet Transaction Name" }

      it "renders correctly" do
        expect(rendered_template).to match_html_snapshot
      end
    end

    context "when wallet transaction has no name" do
      let(:wallet_transaction_name) { nil }

      context "when wallet has no name" do
        let(:wallet_name) { nil }

        it "renders correctly" do
          expect(rendered_template).to match_html_snapshot
        end
      end

      context "when wallet has a name" do
        let(:wallet_name) { "Premium Wallet" }

        it "renders correctly" do
          expect(rendered_template).to match_html_snapshot
        end
      end
    end
  end

  context "when invoice_type is subscription with prepaid credits" do
    let(:organization) { create(:organization, :with_static_values, webhook_url: nil) }
    let(:billing_entity) { create(:billing_entity, :with_static_values, organization:) }
    let(:customer) { create(:customer, :with_static_values, organization:, billing_entity:) }
    let(:plan) { create(:plan, organization:, interval: "monthly", name: "Basic Plan", invoice_display_name: "Basic Plan", code: "basic_plan", amount_cents: 5000, amount_currency: "USD") }
    let(:subscription) { create(:subscription, customer:, organization:, plan:, external_id: "sub_123") }
    let(:wallet) { create(:wallet, customer:, organization:, rate_amount: BigDecimal("1.0"), balance_currency: "USD") }
    let(:wallet_transaction) { create(:wallet_transaction, wallet:, invoice:, credit_amount: BigDecimal("5.0"), amount: BigDecimal("5.0")) }
    let(:subscription_fee) do
      create(
        :fee,
        invoice:,
        subscription:,
        fee_type: :subscription,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 1,
        invoice_display_name: "Basic Plan - Monthly"
      )
    end
    let(:invoice) do
      create(
        :invoice,
        invoice_type: :subscription,
        organization:,
        billing_entity:,
        customer:,
        number: "LAGO-202509-002",
        payment_due_date: Date.parse("2025-09-04"),
        issuing_date: Date.parse("2025-09-04"),
        fees_amount_cents: 5000,
        sub_total_excluding_taxes_amount_cents: 5000,
        sub_total_including_taxes_amount_cents: 5000,
        taxes_amount_cents: 0,
        total_amount_cents: 4500,
        prepaid_credit_amount_cents: 500,
        prepaid_granted_credit_amount_cents:,
        prepaid_purchased_credit_amount_cents:,
        currency: "USD"
      )
    end
    let(:invoice_subscription) do
      create(
        :invoice_subscription,
        invoice:,
        subscription:,
        from_datetime: DateTime.parse("2025-09-01 00:00:00"),
        to_datetime: DateTime.parse("2025-09-30 23:59:59"),
        charges_from_datetime: DateTime.parse("2025-09-01 00:00:00"),
        charges_to_datetime: DateTime.parse("2025-09-30 23:59:59")
      )
    end
    let(:prepaid_granted_credit_amount_cents) { nil }
    let(:prepaid_purchased_credit_amount_cents) { nil }

    before do
      invoice_subscription
      subscription_fee
      wallet_transaction
    end

    context "with only granted credits" do
      let(:prepaid_granted_credit_amount_cents) { 500 }

      it "renders correctly" do
        expect(rendered_template).to match_html_snapshot
      end
    end

    context "with only purchased credits" do
      let(:prepaid_purchased_credit_amount_cents) { 500 }

      it "renders correctly" do
        expect(rendered_template).to match_html_snapshot
      end
    end

    context "with both granted and purchased credits" do
      let(:prepaid_granted_credit_amount_cents) { 300 }
      let(:prepaid_purchased_credit_amount_cents) { 200 }

      it "renders correctly" do
        expect(rendered_template).to match_html_snapshot
      end
    end

    context "without breakdown (legacy behavior)" do
      let(:prepaid_granted_credit_amount_cents) { nil }
      let(:prepaid_purchased_credit_amount_cents) { nil }

      it "renders correctly" do
        expect(rendered_template).to match_html_snapshot
      end
    end
  end

  context "when invoice_type is subscription and plan is paid in arrears" do
    let(:organization) { create(:organization, :with_static_values) }
    let(:customer) { create(:customer, :with_static_values, organization:) }

    let(:plan) do
      create(
        :plan,
        organization:,
        interval: "monthly",
        invoice_display_name: "Pay in Arrears Premium Plan"
      )
    end

    let(:subscription) do
      create(:subscription, customer:, plan:, status: "active")
    end

    let(:invoice) do
      create(
        :invoice,
        customer:,
        number: "LAGO-202509-002",
        payment_due_date: Date.parse("2025-10-01"),
        issuing_date: Date.parse("2025-09-01"),
        invoice_type: :subscription,
        total_amount_cents: 5000,
        currency: "USD",
        fees_amount_cents: 5000,
        sub_total_excluding_taxes_amount_cents: 5000,
        sub_total_including_taxes_amount_cents: 5000
      )
    end

    let(:invoice_subscription) do
      create(
        :invoice_subscription,
        invoice:,
        subscription:,
        from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        charges_from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        charges_to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        fixed_charges_from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        fixed_charges_to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        timestamp: Time.zone.parse("2025-08-31 23:59:59")
      )
    end

    let(:subscription_fee) do
      create(
        :fee,
        invoice:,
        subscription:,
        fee_type: :subscription,
        amount_cents: 1500,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 1500,
        precise_unit_amount: 15.00,
        invoice_display_name: "Pay in Arrears Subscription Fee",
        properties: {
          from_datetime: "2025-08-01 00:00:00",
          to_datetime: "2025-08-31 23:59:59"
        }
      )
    end

    let(:add_on) { create(:add_on, organization: organization) }

    let(:standard_fixed_charge) do
      create(:fixed_charge, :pay_in_advance, plan:, add_on:)
    end
    let(:standard_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: standard_fixed_charge,
        subscription:,
        pay_in_advance: true,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 2,
        unit_amount_cents: 2500,
        precise_unit_amount: 25.00,
        invoice_display_name: "Standard Pay in Advance Fixed Charge Fee",
        properties: {
          fixed_charges_from_datetime: "2025-09-01 00:00:00",
          fixed_charges_to_datetime: "2025-09-30 23:59:59"
        }
      )
    end

    let(:standard_prorated_fixed_charge) do
      create(
        :fixed_charge,
        :pay_in_advance,
        plan:,
        add_on:,
        prorated: true
      )
    end
    let(:standard_prorated_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: standard_prorated_fixed_charge,
        subscription:,
        pay_in_advance: true,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 0.5,
        unit_amount_cents: 10000,
        precise_unit_amount: 100.00,
        invoice_display_name: "Standard Pay in Advance Prorated Fixed Charge Fee",
        properties: {
          fixed_charges_from_datetime: "2025-09-01 00:00:00",
          fixed_charges_to_datetime: "2025-09-30 23:59:59"
        }
      )
    end

    let(:graduated_fixed_charge) do
      create(
        :fixed_charge,
        :graduated,
        :pay_in_advance,
        plan:,
        add_on:
      )
    end
    let(:graduated_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: graduated_fixed_charge,
        subscription:,
        pay_in_advance: true,
        amount_cents: 55500,
        amount_currency: "USD",
        units: 15,
        unit_amount_cents: 3700,
        precise_unit_amount: 37.00,
        invoice_display_name: "Graduated Pay in Advance Fixed Charge Fee",
        amount_details: {
          "graduated_ranges" => [
            {
              "from_value" => 0,
              "to_value" => 10,
              "units" => 10.0,
              "per_unit_amount" => "5.0",
              "per_unit_total_amount" => "50.0",
              "flat_unit_amount" => "200.0"
            },
            {
              "from_value" => 11,
              "to_value" => nil,
              "units" => 5.0,
              "per_unit_amount" => "1.0",
              "per_unit_total_amount" => "5.0",
              "flat_unit_amount" => "300.0"
            }
          ]
        },
        properties: {
          fixed_charges_from_datetime: "2025-09-01 00:00:00",
          fixed_charges_to_datetime: "2025-09-30 23:59:59"
        }
      )
    end

    let(:zero_fixed_charge) do
      create(
        :fixed_charge,
        :pay_in_advance,
        plan:,
        add_on:
      )
    end
    let(:zero_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: zero_fixed_charge,
        subscription:,
        pay_in_advance: true,
        amount_cents: 0,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 0,
        precise_unit_amount: 0.00,
        invoice_display_name: "Zero Pay in Advance Fixed Charge Fee",
        properties: {
          fixed_charges_from_datetime: "2025-09-01 00:00:00",
          fixed_charges_to_datetime: "2025-09-30 23:59:59"
        }
      )
    end

    let(:arrears_fixed_charge) do
      create(
        :fixed_charge,
        plan:,
        add_on:
      )
    end
    let(:arrears_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: arrears_fixed_charge,
        subscription:,
        amount_cents: 8500,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 8500,
        precise_unit_amount: 85.00,
        invoice_display_name: "Standard Pay in Arrears Fixed Charge Fee",
        properties: {
          fixed_charges_from_datetime: "2025-08-01 00:00:00",
          fixed_charges_to_datetime: "2025-08-31 23:59:59"
        }
      )
    end

    let(:arrears_graduated_fixed_charge) do
      create(
        :fixed_charge,
        :graduated,
        plan:,
        add_on:
      )
    end
    let(:arrears_graduated_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: arrears_graduated_fixed_charge,
        subscription:,
        amount_cents: 55500,
        amount_currency: "USD",
        units: 15,
        unit_amount_cents: 3700,
        precise_unit_amount: 37.00,
        invoice_display_name: "Graduated Pay in Arrears Fixed Charge Fee",
        amount_details: {
          "graduated_ranges" => [
            {
              "from_value" => 0,
              "to_value" => 10,
              "units" => 10.0,
              "per_unit_amount" => "5.0",
              "per_unit_total_amount" => "50.0",
              "flat_unit_amount" => "200.0"
            },
            {
              "from_value" => 11,
              "to_value" => nil,
              "units" => 5.0,
              "per_unit_amount" => "1.0",
              "per_unit_total_amount" => "5.0",
              "flat_unit_amount" => "300.0"
            }
          ]
        },
        properties: {
          fixed_charges_from_datetime: "2025-08-01 00:00:00",
          fixed_charges_to_datetime: "2025-08-31 23:59:59"
        }
      )
    end

    let(:arrears_graduated_prorated_fixed_charge) do
      create(
        :fixed_charge,
        :graduated,
        plan:,
        add_on:,
        prorated: true
      )
    end
    let(:arrears_graduated_prorated_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: arrears_graduated_prorated_fixed_charge,
        subscription:,
        amount_cents: 55500,
        amount_currency: "USD",
        units: 15,
        unit_amount_cents: 3700,
        precise_unit_amount: 37.00,
        invoice_display_name: "Graduated Pay in Arrears Prorated Fixed Charge Fee",
        amount_details: {
          "graduated_ranges" => [
            {
              "from_value" => 0,
              "to_value" => 10,
              "units" => 10.0,
              "per_unit_amount" => "5.0",
              "per_unit_total_amount" => "50.0",
              "flat_unit_amount" => "200.0"
            },
            {
              "from_value" => 11,
              "to_value" => nil,
              "units" => 5.0,
              "per_unit_amount" => "1.0",
              "per_unit_total_amount" => "5.0",
              "flat_unit_amount" => "300.0"
            }
          ]
        },
        properties: {
          fixed_charges_from_datetime: "2025-08-01 00:00:00",
          fixed_charges_to_datetime: "2025-08-31 23:59:59"
        }
      )
    end

    let(:volume_fixed_charge) do
      create(
        :fixed_charge,
        :volume,
        plan:,
        add_on:
      )
    end
    let(:volume_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: volume_fixed_charge,
        subscription:,
        amount_cents: 15100,
        amount_currency: "USD",
        units: 75,
        unit_amount_cents: 201,
        precise_unit_amount: 2.01,
        invoice_display_name: "Volume Pay in Arrears Fixed Charge Fee",
        amount_details: {
          "per_unit_amount" => "2.0",
          "per_unit_total_amount" => "150.0",
          "flat_unit_amount" => "1.0"
        },
        properties: {
          fixed_charges_from_datetime: "2025-08-01 00:00:00",
          fixed_charges_to_datetime: "2025-08-31 23:59:59"
        }
      )
    end

    let(:volume_prorated_fixed_charge) do
      create(
        :fixed_charge,
        :volume,
        plan:,
        add_on:,
        prorated: true
      )
    end
    let(:volume_prorated_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: volume_prorated_fixed_charge,
        subscription:,
        amount_cents: 9200,
        amount_currency: "USD",
        units: 30,
        unit_amount_cents: 307,
        precise_unit_amount: 3.07,
        invoice_display_name: "Volume Pay in Arrears Prorated Fixed Charge Fee",
        amount_details: {
          "per_unit_amount" => "3.0",
          "per_unit_total_amount" => "90.0",
          "flat_unit_amount" => "2.0"
        },
        properties: {
          fixed_charges_from_datetime: "2025-08-01 00:00:00",
          fixed_charges_to_datetime: "2025-08-31 23:59:59"
        }
      )
    end

    let(:minimum_commitment_fee) do
      create(
        :minimum_commitment_fee,
        invoice:,
        subscription:,
        amount_currency: "USD",
        invoice_display_name: "Minimum Commitment Fee"
      )
    end

    before do
      invoice_subscription
      subscription_fee
      minimum_commitment_fee
      standard_fixed_charge_fee
      standard_prorated_fixed_charge_fee
      graduated_fixed_charge_fee
      zero_fixed_charge_fee
      arrears_fixed_charge_fee
      arrears_graduated_fixed_charge_fee
      arrears_graduated_prorated_fixed_charge_fee
      volume_fixed_charge_fee
      volume_prorated_fixed_charge_fee
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "when invoice has different boundaries for fixed charges" do
    let(:organization) { create(:organization, :with_static_values) }
    let(:customer) { create(:customer, :with_static_values, organization:) }

    let(:plan) do
      create(
        :plan,
        organization:,
        interval: "yearly",
        pay_in_advance: false,
        invoice_display_name: "Annual Plan",
        bill_fixed_charges_monthly: true
      )
    end

    let(:subscription) do
      create(
        :subscription,
        customer:,
        plan:,
        status: "active"
      )
    end

    let(:invoice) do
      create(
        :invoice,
        customer:,
        number: "LAGO-202509-003",
        payment_due_date: Date.parse("2026-01-01"),
        issuing_date: Date.parse("2026-01-01"),
        invoice_type: :subscription,
        total_amount_cents: 5000,
        currency: "EUR",
        fees_amount_cents: 5000,
        sub_total_excluding_taxes_amount_cents: 5000,
        sub_total_including_taxes_amount_cents: 5000
      )
    end

    let(:invoice_subscription) do
      create(
        :invoice_subscription,
        invoice: invoice,
        subscription: subscription,
        organization: organization,
        from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        to_datetime: Time.zone.parse("2025-12-31 23:59:59"),
        charges_from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        charges_to_datetime: Time.zone.parse("2025-12-31 23:59:59"),
        fixed_charges_from_datetime: Time.zone.parse("2025-12-01 00:00:00"),
        fixed_charges_to_datetime: Time.zone.parse("2025-12-31 23:59:59"),
        timestamp: Time.zone.parse("2025-12-31 23:59:59")
      )
    end

    let(:subscription_fee) do
      create(
        :fee,
        invoice:,
        subscription:,
        fee_type: :subscription,
        amount_cents: 99900,
        amount_currency: "EUR",
        units: 1,
        unit_amount_cents: 99900,
        precise_unit_amount: 999.00,
        invoice_display_name: nil,
        properties: {
          from_datetime: "2025-08-01 00:00:00",
          to_datetime: "2025-12-31 23:59:59"
        }
      )
    end

    let(:add_on) { create(:add_on, organization:) }
    let(:monthly_fixed_charge) do
      create(
        :fixed_charge,
        plan:,
        add_on:
      )
    end
    let(:monthly_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        subscription:,
        fixed_charge: monthly_fixed_charge,
        amount_cents: 10000,
        amount_currency: "EUR",
        units: 1,
        unit_amount_cents: 10000,
        precise_unit_amount: 100.00,
        invoice_display_name: "Monthly Fixed Charge",
        properties: {
          from_datetime: "2025-12-01 00:00:00",
          to_datetime: "2025-12-31 23:59:59"
        }
      )
    end

    before do
      invoice_subscription
      subscription_fee
      monthly_fixed_charge_fee
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "when invoice_type is subscription and plan is paid in advance" do
    let(:organization) { create(:organization, :with_static_values) }
    let(:customer) { create(:customer, :with_static_values, organization:) }

    let(:plan) do
      create(
        :plan,
        organization:,
        interval: "monthly",
        pay_in_advance: true,
        invoice_display_name: "Premium Plan"
      )
    end

    let(:subscription) do
      create(:subscription, customer:, plan:, status: "active")
    end

    let(:invoice) do
      create(
        :invoice,
        customer:,
        number: "LAGO-202509-002",
        payment_due_date: Date.parse("2025-09-19"),
        issuing_date: Date.parse("2025-09-04"),
        invoice_type: :subscription,
        total_amount_cents: 5000,
        currency: "USD",
        fees_amount_cents: 5000,
        sub_total_excluding_taxes_amount_cents: 5000,
        sub_total_including_taxes_amount_cents: 5000
      )
    end

    let(:invoice_subscription) do
      create(
        :invoice_subscription,
        invoice:,
        subscription:,
        from_datetime: Time.zone.parse("2025-09-01 00:00:00"),
        to_datetime: Time.zone.parse("2025-09-30 23:59:59"),
        charges_from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        charges_to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        fixed_charges_from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        fixed_charges_to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        timestamp: Time.zone.parse("2025-08-31 23:59:59")
      )
    end

    let(:subscription_fee) do
      create(
        :fee,
        invoice:,
        subscription:,
        pay_in_advance: true,
        fee_type: :subscription,
        amount_cents: 1500,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 1500,
        precise_unit_amount: 15.00,
        invoice_display_name: "Pay in Advance Subscription Fee",
        properties: {
          from_datetime: "2025-09-01 00:00:00",
          to_datetime: "2025-09-30 23:59:59"
        }
      )
    end

    let(:add_on) { create(:add_on, organization: organization) }

    let(:previous_invoice) do
      create(:invoice, customer:)
    end
    let(:previous_invoice_subscription) do
      create(
        :invoice_subscription,
        subscription:,
        invoice: previous_invoice,
        from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        charges_from_datetime: Time.zone.parse("2025-07-01 00:00:00"),
        charges_to_datetime: Time.zone.parse("2025-07-31 23:59:59"),
        fixed_charges_from_datetime: Time.zone.parse("2025-07-01 00:00:00"),
        fixed_charges_to_datetime: Time.zone.parse("2025-07-31 23:59:59"),
        timestamp: Time.zone.parse("2025-07-31 23:59:59")
      )
    end
    let(:previous_subscription_fee) do
      create(
        :fee,
        invoice: previous_invoice,
        subscription:,
        pay_in_advance: true,
        fee_type: :subscription,
        amount_cents: 1500,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 1500,
        precise_unit_amount: 15.00,
        properties: {
          from_datetime: "2025-08-01 00:00:00",
          to_datetime: "2025-08-31 23:59:59"
        }
      )
    end

    let(:standard_fixed_charge) do
      create(:fixed_charge, :pay_in_advance, plan:, add_on:)
    end
    let(:standard_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: standard_fixed_charge,
        subscription:,
        pay_in_advance: true,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 2,
        unit_amount_cents: 2500,
        precise_unit_amount: 25.00,
        invoice_display_name: "Standard Pay in Advance Fixed Charge Fee",
        properties: {
          fixed_charges_from_datetime: "2025-09-01 00:00:00",
          fixed_charges_to_datetime: "2025-09-30 23:59:59"
        }
      )
    end

    let(:standard_prorated_fixed_charge) do
      create(
        :fixed_charge,
        :pay_in_advance,
        plan:,
        add_on:,
        prorated: true
      )
    end
    let(:standard_prorated_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: standard_prorated_fixed_charge,
        subscription:,
        pay_in_advance: true,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 0.5,
        unit_amount_cents: 10000,
        precise_unit_amount: 100.00,
        invoice_display_name: "Standard Pay in Advance Prorated Fixed Charge Fee",
        properties: {
          fixed_charges_from_datetime: "2025-09-01 00:00:00",
          fixed_charges_to_datetime: "2025-09-30 23:59:59"
        }
      )
    end

    let(:graduated_fixed_charge) do
      create(
        :fixed_charge,
        :graduated,
        :pay_in_advance,
        plan:,
        add_on:
      )
    end
    let(:graduated_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: graduated_fixed_charge,
        subscription:,
        pay_in_advance: true,
        amount_cents: 55500,
        amount_currency: "USD",
        units: 15,
        unit_amount_cents: 3700,
        precise_unit_amount: 37.00,
        invoice_display_name: "Graduated Pay in Advance Fixed Charge Fee",
        amount_details: {
          "graduated_ranges" => [
            {
              "from_value" => 0,
              "to_value" => 10,
              "units" => 10.0,
              "per_unit_amount" => "5.0",
              "per_unit_total_amount" => "50.0",
              "flat_unit_amount" => "200.0"
            },
            {
              "from_value" => 11,
              "to_value" => nil,
              "units" => 5.0,
              "per_unit_amount" => "1.0",
              "per_unit_total_amount" => "5.0",
              "flat_unit_amount" => "300.0"
            }
          ]
        },
        properties: {
          fixed_charges_from_datetime: "2025-09-01 00:00:00",
          fixed_charges_to_datetime: "2025-09-30 23:59:59"
        }
      )
    end

    let(:zero_fixed_charge) do
      create(
        :fixed_charge,
        :pay_in_advance,
        plan:,
        add_on:
      )
    end
    let(:zero_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: zero_fixed_charge,
        subscription:,
        pay_in_advance: true,
        amount_cents: 0,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 0,
        precise_unit_amount: 0.00,
        invoice_display_name: "Zero Pay in Advance Fixed Charge Fee",
        properties: {
          fixed_charges_from_datetime: "2025-09-01 00:00:00",
          fixed_charges_to_datetime: "2025-09-30 23:59:59"
        }
      )
    end

    let(:arrears_fixed_charge) do
      create(
        :fixed_charge,
        plan:,
        add_on:
      )
    end
    let(:arrears_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: arrears_fixed_charge,
        subscription:,
        amount_cents: 8500,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 8500,
        precise_unit_amount: 85.00,
        invoice_display_name: "Standard Pay in Arrears Fixed Charge Fee",
        properties: {
          fixed_charges_from_datetime: "2025-08-01 00:00:00",
          fixed_charges_to_datetime: "2025-08-31 23:59:59"
        }
      )
    end

    let(:arrears_graduated_fixed_charge) do
      create(
        :fixed_charge,
        :graduated,
        plan:,
        add_on:
      )
    end
    let(:arrears_graduated_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: arrears_graduated_fixed_charge,
        subscription:,
        amount_cents: 55500,
        amount_currency: "USD",
        units: 15,
        unit_amount_cents: 3700,
        precise_unit_amount: 37.00,
        invoice_display_name: "Graduated Pay in Arrears Fixed Charge Fee",
        amount_details: {
          "graduated_ranges" => [
            {
              "from_value" => 0,
              "to_value" => 10,
              "units" => 10.0,
              "per_unit_amount" => "5.0",
              "per_unit_total_amount" => "50.0",
              "flat_unit_amount" => "200.0"
            },
            {
              "from_value" => 11,
              "to_value" => nil,
              "units" => 5.0,
              "per_unit_amount" => "1.0",
              "per_unit_total_amount" => "5.0",
              "flat_unit_amount" => "300.0"
            }
          ]
        },
        properties: {
          fixed_charges_from_datetime: "2025-08-01 00:00:00",
          fixed_charges_to_datetime: "2025-08-31 23:59:59"
        }
      )
    end

    let(:arrears_graduated_prorated_fixed_charge) do
      create(
        :fixed_charge,
        :graduated,
        plan:,
        add_on:,
        prorated: true
      )
    end
    let(:arrears_graduated_prorated_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: arrears_graduated_prorated_fixed_charge,
        subscription:,
        amount_cents: 55500,
        amount_currency: "USD",
        units: 15,
        unit_amount_cents: 3700,
        precise_unit_amount: 37.00,
        invoice_display_name: "Graduated Pay in Arrears Prorated Fixed Charge Fee",
        amount_details: {
          "graduated_ranges" => [
            {
              "from_value" => 0,
              "to_value" => 10,
              "units" => 10.0,
              "per_unit_amount" => "5.0",
              "per_unit_total_amount" => "50.0",
              "flat_unit_amount" => "200.0"
            },
            {
              "from_value" => 11,
              "to_value" => nil,
              "units" => 5.0,
              "per_unit_amount" => "1.0",
              "per_unit_total_amount" => "5.0",
              "flat_unit_amount" => "300.0"
            }
          ]
        },
        properties: {
          fixed_charges_from_datetime: "2025-08-01 00:00:00",
          fixed_charges_to_datetime: "2025-08-31 23:59:59"
        }
      )
    end

    let(:volume_fixed_charge) do
      create(
        :fixed_charge,
        :volume,
        plan:,
        add_on:
      )
    end
    let(:volume_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: volume_fixed_charge,
        subscription:,
        amount_cents: 15100,
        amount_currency: "USD",
        units: 75,
        unit_amount_cents: 201,
        precise_unit_amount: 2.01,
        invoice_display_name: "Volume Pay in Arrears Fixed Charge Fee",
        amount_details: {
          "per_unit_amount" => "2.0",
          "per_unit_total_amount" => "150.0",
          "flat_unit_amount" => "1.0"
        },
        properties: {
          fixed_charges_from_datetime: "2025-08-01 00:00:00",
          fixed_charges_to_datetime: "2025-08-31 23:59:59"
        }
      )
    end

    let(:volume_prorated_fixed_charge) do
      create(
        :fixed_charge,
        :volume,
        plan:,
        add_on:,
        prorated: true
      )
    end
    let(:volume_prorated_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: volume_prorated_fixed_charge,
        subscription:,
        amount_cents: 9200,
        amount_currency: "USD",
        units: 30,
        unit_amount_cents: 307,
        precise_unit_amount: 3.07,
        invoice_display_name: "Volume Pay in Arrears Prorated Fixed Charge Fee",
        amount_details: {
          "per_unit_amount" => "3.0",
          "per_unit_total_amount" => "90.0",
          "flat_unit_amount" => "2.0"
        },
        properties: {
          fixed_charges_from_datetime: "2025-08-01 00:00:00",
          fixed_charges_to_datetime: "2025-08-31 23:59:59"
        }
      )
    end

    let(:minimum_commitment_fee) do
      create(
        :minimum_commitment_fee,
        invoice:,
        subscription:,
        amount_currency: "USD",
        invoice_display_name: "Minimum Commitment Fee"
      )
    end

    before do
      previous_invoice_subscription
      previous_subscription_fee

      invoice_subscription
      subscription_fee
      minimum_commitment_fee
      standard_fixed_charge_fee
      standard_prorated_fixed_charge_fee
      graduated_fixed_charge_fee
      zero_fixed_charge_fee
      arrears_fixed_charge_fee
      arrears_graduated_fixed_charge_fee
      arrears_graduated_prorated_fixed_charge_fee
      volume_fixed_charge_fee
      volume_prorated_fixed_charge_fee
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "when invoice_type is progressive_billing with prepaid credits" do
    let(:organization) { create(:organization, :with_static_values) }
    let(:customer) { create(:customer, :with_static_values, organization:) }
    let(:billable_metric) { create(:billable_metric, organization:) }

    let(:plan) do
      create(
        :plan,
        organization:,
        interval: "monthly",
        pay_in_advance: false,
        invoice_display_name: "Progressive Billing Plan"
      )
    end

    let(:charge) do
      create(
        :standard_charge,
        plan:,
        billable_metric:,
        invoice_display_name: "Usage Charge"
      )
    end

    let(:usage_threshold) do
      create(:usage_threshold, plan:, amount_cents: 10000)
    end

    let(:subscription) do
      create(:subscription, customer:, plan:, status: "active")
    end

    let(:wallet) { create(:wallet, customer:, organization:, rate_amount: BigDecimal("1.0"), balance_currency: "USD") }
    let(:wallet_transaction) { create(:wallet_transaction, wallet:, invoice:, credit_amount: BigDecimal("5.0"), amount: BigDecimal("5.0")) }

    let(:invoice) do
      create(
        :invoice,
        customer:,
        number: "LAGO-202509-008",
        payment_due_date: Date.parse("2025-09-15"),
        issuing_date: Date.parse("2025-09-15"),
        invoice_type: :progressive_billing,
        total_amount_cents: 9500,
        currency: "USD",
        fees_amount_cents: 10000,
        sub_total_excluding_taxes_amount_cents: 10000,
        sub_total_including_taxes_amount_cents: 10000,
        prepaid_credit_amount_cents: 500,
        prepaid_granted_credit_amount_cents: 200,
        prepaid_purchased_credit_amount_cents: 300
      )
    end

    let(:invoice_subscription) do
      create(
        :invoice_subscription,
        invoice:,
        subscription:,
        from_datetime: Time.zone.parse("2025-09-01 00:00:00"),
        to_datetime: Time.zone.parse("2025-09-30 23:59:59"),
        charges_from_datetime: Time.zone.parse("2025-09-01 00:00:00"),
        charges_to_datetime: Time.zone.parse("2025-09-15 23:59:59"),
        fixed_charges_from_datetime: Time.zone.parse("2025-09-01 00:00:00"),
        fixed_charges_to_datetime: Time.zone.parse("2025-09-15 23:59:59"),
        timestamp: Time.zone.parse("2025-09-15 12:00:00")
      )
    end

    let(:charge_fee) do
      create(
        :charge_fee,
        invoice:,
        subscription:,
        charge:,
        amount_cents: 10000,
        amount_currency: "USD",
        units: 100,
        unit_amount_cents: 100,
        precise_unit_amount: 1.00,
        invoice_display_name: "Usage Charge Fee",
        properties: {
          "timestamp" => "2025-09-15 12:00:00",
          "charges_from_datetime" => "2025-09-01 00:00:00",
          "charges_to_datetime" => "2025-09-15 23:59:59"
        }
      )
    end

    let(:applied_usage_threshold) do
      create(
        :applied_usage_threshold,
        invoice:,
        usage_threshold:,
        lifetime_usage_amount_cents: 10000
      )
    end

    before do
      invoice_subscription
      charge_fee
      wallet_transaction
      applied_usage_threshold
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end

    context "when invoice does not have any applied usage threshold" do
      let(:applied_usage_threshold) { nil }

      it "renders without the reached usage threshold line" do
        expect(rendered_template).not_to include("This progressive billing is generated because your cumulative usage has reached")
      end
    end
  end

  context "when charge has filters and minimum commitment (true_up fee)" do
    let(:organization) { create(:organization, :with_static_values) }
    let(:customer) { create(:customer, :with_static_values, organization:) }
    let(:billable_metric) { create(:billable_metric, organization:) }

    let(:plan) do
      create(
        :plan,
        organization:,
        interval: "monthly",
        pay_in_advance: false,
        invoice_display_name: "Plan with Charge Filters"
      )
    end

    let(:subscription) do
      create(:subscription, customer:, plan:, status: "active")
    end

    let(:charge) do
      create(
        :standard_charge,
        plan:,
        billable_metric:,
        min_amount_cents: 10000,
        invoice_display_name: "Usage Charge with Minimum"
      )
    end

    let(:billable_metric_filter) do
      create(:billable_metric_filter, billable_metric:, key: "region", values: ["us", "eu", "asia"])
    end

    let(:charge_filter_1) do
      filter = create(:charge_filter, charge:, properties: {amount: "10"})
      create(:charge_filter_value, charge_filter: filter, billable_metric_filter:, values: ["us"])
      filter
    end

    let(:charge_filter_2) do
      filter = create(:charge_filter, charge:, properties: {amount: "20"})
      create(:charge_filter_value, charge_filter: filter, billable_metric_filter:, values: ["eu"])
      filter
    end

    let(:invoice) do
      create(
        :invoice,
        customer:,
        number: "LAGO-202509-004",
        payment_due_date: Date.parse("2025-10-01"),
        issuing_date: Date.parse("2025-09-01"),
        invoice_type: :subscription,
        total_amount_cents: 10000,
        currency: "USD",
        fees_amount_cents: 10000,
        sub_total_excluding_taxes_amount_cents: 10000,
        sub_total_including_taxes_amount_cents: 10000
      )
    end

    let(:invoice_subscription) do
      create(
        :invoice_subscription,
        invoice:,
        subscription:,
        from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        charges_from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        charges_to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        fixed_charges_from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        fixed_charges_to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        timestamp: Time.zone.parse("2025-08-31 23:59:59")
      )
    end

    let(:base_charge_fee) do
      create(
        :charge_fee,
        invoice:,
        subscription:,
        charge:,
        charge_filter: nil,
        amount_cents: 0,
        amount_currency: "USD",
        units: 0,
        unit_amount_cents: 0,
        precise_unit_amount: 0,
        total_aggregated_units: 0,
        invoice_display_name: nil,
        properties: {
          "timestamp" => "2025-08-31 23:59:59",
          "charges_from_datetime" => "2025-08-01 00:00:00",
          "charges_to_datetime" => "2025-08-31 23:59:59"
        }
      )
    end

    let(:filter_1_fee) do
      create(
        :charge_fee,
        invoice:,
        subscription:,
        charge:,
        charge_filter: charge_filter_1,
        amount_cents: 3000,
        amount_currency: "USD",
        units: 3,
        unit_amount_cents: 1000,
        precise_unit_amount: 10.00,
        total_aggregated_units: 3,
        invoice_display_name: nil,
        properties: {
          "timestamp" => "2025-08-31 23:59:59",
          "charges_from_datetime" => "2025-08-01 00:00:00",
          "charges_to_datetime" => "2025-08-31 23:59:59"
        }
      )
    end

    let(:filter_2_fee) do
      create(
        :charge_fee,
        invoice:,
        subscription:,
        charge:,
        charge_filter: charge_filter_2,
        amount_cents: 4000,
        amount_currency: "USD",
        units: 2,
        unit_amount_cents: 2000,
        precise_unit_amount: 20.00,
        total_aggregated_units: 2,
        invoice_display_name: nil,
        properties: {
          "timestamp" => "2025-08-31 23:59:59",
          "charges_from_datetime" => "2025-08-01 00:00:00",
          "charges_to_datetime" => "2025-08-31 23:59:59"
        }
      )
    end

    let(:true_up_fee) do
      create(
        :charge_fee,
        invoice:,
        subscription:,
        charge:,
        charge_filter: nil,
        true_up_parent_fee: base_charge_fee,
        amount_cents: 3000,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 3000,
        precise_unit_amount: 30.00,
        total_aggregated_units: 1,
        events_count: 0,
        invoice_display_name: nil,
        properties: {
          "timestamp" => "2025-08-31 23:59:59",
          "charges_from_datetime" => "2025-08-01 00:00:00",
          "charges_to_datetime" => "2025-08-31 23:59:59"
        }
      )
    end

    before do
      invoice_subscription
      base_charge_fee
      filter_1_fee
      filter_2_fee
      true_up_fee
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "when invoice has multiple subscriptions" do
    let(:organization) { create(:organization, :with_static_values) }
    let(:customer) { create(:customer, :with_static_values, organization:) }

    # Plans are named to test alphabetical ordering - Zebra comes after Alpha alphabetically
    # but we create Zebra first to verify the ordering is by name, not insertion order
    let(:plan_zebra) do
      create(
        :plan,
        organization:,
        interval: "monthly",
        pay_in_advance: false,
        invoice_display_name: "Zebra Plan"
      )
    end

    let(:plan_alpha) do
      create(
        :plan,
        organization:,
        interval: "monthly",
        pay_in_advance: false,
        invoice_display_name: "Alpha Plan"
      )
    end

    # Create Zebra subscription first to ensure ordering is alphabetical, not by insertion
    let(:subscription_zebra) do
      create(:subscription, customer:, plan: plan_zebra, status: "active")
    end

    let(:subscription_alpha) do
      create(:subscription, customer:, plan: plan_alpha, status: "active")
    end

    let(:invoice) do
      create(
        :invoice,
        customer:,
        number: "LAGO-202509-005",
        payment_due_date: Date.parse("2025-10-01"),
        issuing_date: Date.parse("2025-09-01"),
        invoice_type: :subscription,
        total_amount_cents: 8000,
        currency: "USD",
        fees_amount_cents: 8000,
        sub_total_excluding_taxes_amount_cents: 8000,
        sub_total_including_taxes_amount_cents: 8000
      )
    end

    # Create Zebra invoice_subscription first (will be created before Alpha)
    let(:invoice_subscription_zebra) do
      create(
        :invoice_subscription,
        invoice:,
        subscription: subscription_zebra,
        from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        charges_from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        charges_to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        fixed_charges_from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        fixed_charges_to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        timestamp: Time.zone.parse("2025-08-31 23:59:59")
      )
    end

    let(:invoice_subscription_alpha) do
      create(
        :invoice_subscription,
        invoice:,
        subscription: subscription_alpha,
        from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        charges_from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        charges_to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        fixed_charges_from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        fixed_charges_to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        timestamp: Time.zone.parse("2025-08-31 23:59:59")
      )
    end

    let(:subscription_fee_zebra) do
      create(
        :fee,
        invoice:,
        subscription: subscription_zebra,
        fee_type: :subscription,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 5000,
        precise_unit_amount: 50.00,
        invoice_display_name: "Zebra Plan Subscription",
        properties: {
          from_datetime: "2025-08-01 00:00:00",
          to_datetime: "2025-08-31 23:59:59"
        }
      )
    end

    let(:subscription_fee_alpha) do
      create(
        :fee,
        invoice:,
        subscription: subscription_alpha,
        fee_type: :subscription,
        amount_cents: 3000,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 3000,
        precise_unit_amount: 30.00,
        invoice_display_name: "Alpha Plan Subscription",
        properties: {
          from_datetime: "2025-08-01 00:00:00",
          to_datetime: "2025-08-31 23:59:59"
        }
      )
    end

    before do
      # Create Zebra first, then Alpha - but rendered output should show Alpha first (alphabetical)
      invoice_subscription_zebra
      invoice_subscription_alpha
      subscription_fee_zebra
      subscription_fee_alpha
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "when charge fees have presentation breakdowns" do
    let(:organization) { create(:organization, :with_static_values) }
    let(:customer) { create(:customer, :with_static_values, organization:) }
    let(:billable_metric) { create(:billable_metric, organization:) }

    let(:plan) do
      create(
        :plan,
        organization:,
        interval: "monthly",
        pay_in_advance: false,
        invoice_display_name: "Plan with Breakdowns"
      )
    end

    let(:subscription) { create(:subscription, customer:, plan:, status: "active") }

    let(:charge) do
      create(
        :standard_charge,
        plan:,
        billable_metric:,
        invoice_display_name: "Compute",
        properties: {
          "amount" => "100",
          "presentation_group_keys" => [
            {"value" => "region", "options" => {"display_in_invoice" => true}},
            {"value" => "env", "options" => {"display_in_invoice" => true}}
          ]
        }
      )
    end

    let(:invoice) do
      create(
        :invoice,
        customer:,
        number: "LAGO-202509-009",
        payment_due_date: Date.parse("2025-10-01"),
        issuing_date: Date.parse("2025-09-01"),
        invoice_type: :subscription,
        total_amount_cents: 10000,
        currency: "USD",
        fees_amount_cents: 10000,
        sub_total_excluding_taxes_amount_cents: 10000,
        sub_total_including_taxes_amount_cents: 10000
      )
    end

    let(:invoice_subscription) do
      create(
        :invoice_subscription,
        invoice:,
        subscription:,
        from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        charges_from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        charges_to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        fixed_charges_from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        fixed_charges_to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        timestamp: Time.zone.parse("2025-08-31 23:59:59")
      )
    end

    let(:charge_fee) do
      create(
        :charge_fee,
        invoice:,
        subscription:,
        charge:,
        amount_cents: 10000,
        amount_currency: "USD",
        units: 100,
        unit_amount_cents: 100,
        precise_unit_amount: 1.00,
        invoice_display_name: "Compute",
        grouped_by: {},
        properties: {
          "timestamp" => "2025-08-31 23:59:59",
          "charges_from_datetime" => "2025-08-01 00:00:00",
          "charges_to_datetime" => "2025-08-31 23:59:59"
        }
      )
    end

    before do
      invoice_subscription
      charge_fee
      create(:presentation_breakdown, fee: charge_fee, units: 60, presentation_by: {"region" => "us", "env" => "prod"})
      create(:presentation_breakdown, fee: charge_fee, units: 40, presentation_by: {"region" => "eu", "env" => "prod"})
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "when invoice has multiple subscriptions with prepaid credits" do
    let(:organization) { create(:organization, :with_static_values) }
    let(:customer) { create(:customer, :with_static_values, organization:) }

    let(:plan_alpha) do
      create(
        :plan,
        organization:,
        interval: "monthly",
        pay_in_advance: false,
        invoice_display_name: "Alpha Plan"
      )
    end

    let(:plan_beta) do
      create(
        :plan,
        organization:,
        interval: "monthly",
        pay_in_advance: false,
        invoice_display_name: "Beta Plan"
      )
    end

    let(:subscription_alpha) do
      create(:subscription, customer:, plan: plan_alpha, status: "active")
    end

    let(:subscription_beta) do
      create(:subscription, customer:, plan: plan_beta, status: "active")
    end

    let(:wallet) { create(:wallet, customer:, organization:, rate_amount: BigDecimal("1.0"), balance_currency: "USD") }
    let(:wallet_transaction) { create(:wallet_transaction, wallet:, invoice:, credit_amount: BigDecimal("10.0"), amount: BigDecimal("10.0")) }

    let(:invoice) do
      create(
        :invoice,
        customer:,
        number: "LAGO-202509-006",
        payment_due_date: Date.parse("2025-10-01"),
        issuing_date: Date.parse("2025-09-01"),
        invoice_type: :subscription,
        total_amount_cents: 7000,
        currency: "USD",
        fees_amount_cents: 8000,
        sub_total_excluding_taxes_amount_cents: 8000,
        sub_total_including_taxes_amount_cents: 8000,
        prepaid_credit_amount_cents: 1000,
        prepaid_granted_credit_amount_cents: 400,
        prepaid_purchased_credit_amount_cents: 600
      )
    end

    let(:invoice_subscription_alpha) do
      create(
        :invoice_subscription,
        invoice:,
        subscription: subscription_alpha,
        from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        charges_from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        charges_to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        fixed_charges_from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        fixed_charges_to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        timestamp: Time.zone.parse("2025-08-31 23:59:59")
      )
    end

    let(:invoice_subscription_beta) do
      create(
        :invoice_subscription,
        invoice:,
        subscription: subscription_beta,
        from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        charges_from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        charges_to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        fixed_charges_from_datetime: Time.zone.parse("2025-08-01 00:00:00"),
        fixed_charges_to_datetime: Time.zone.parse("2025-08-31 23:59:59"),
        timestamp: Time.zone.parse("2025-08-31 23:59:59")
      )
    end

    let(:subscription_fee_alpha) do
      create(
        :fee,
        invoice:,
        subscription: subscription_alpha,
        fee_type: :subscription,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 5000,
        precise_unit_amount: 50.00,
        invoice_display_name: "Alpha Plan Subscription",
        properties: {
          from_datetime: "2025-08-01 00:00:00",
          to_datetime: "2025-08-31 23:59:59"
        }
      )
    end

    let(:subscription_fee_beta) do
      create(
        :fee,
        invoice:,
        subscription: subscription_beta,
        fee_type: :subscription,
        amount_cents: 3000,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 3000,
        precise_unit_amount: 30.00,
        invoice_display_name: "Beta Plan Subscription",
        properties: {
          from_datetime: "2025-08-01 00:00:00",
          to_datetime: "2025-08-31 23:59:59"
        }
      )
    end

    before do
      invoice_subscription_alpha
      invoice_subscription_beta
      subscription_fee_alpha
      subscription_fee_beta
      wallet_transaction
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end
end
