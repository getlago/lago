# frozen_string_literal: true

require "rails_helper"

RSpec.describe Commitments::Minimum::CalculateTrueUpFeeService do
  subject(:service) { described_class.new_instance(invoice_subscription:) }

  let(:invoice_subscription) do
    create(
      :invoice_subscription,
      subscription:,
      from_datetime:,
      to_datetime:,
      charges_from_datetime:,
      charges_to_datetime:,
      fixed_charges_from_datetime:,
      fixed_charges_to_datetime:,
      timestamp:
    )
  end

  let(:from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
  let(:to_datetime) { DateTime.parse("2024-12-31T23:59:59.999") }
  let(:charges_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
  let(:charges_to_datetime) { DateTime.parse("2024-12-31T23:59:59.999") }
  let(:fixed_charges_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
  let(:fixed_charges_to_datetime) { DateTime.parse("2024-12-31T23:59:59.999") }
  let(:timestamp) { DateTime.parse("2025-01-01T10:00:00") }
  let(:subscription) { create(:subscription, customer:, plan:, billing_time:, subscription_at:) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription_at) { DateTime.parse("2024-01-01T00:00:00") }
  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:, pay_in_advance:, interval:, bill_charges_monthly:, bill_fixed_charges_monthly:) }
  let(:billing_time) { :calendar }
  let(:bill_charges_monthly) { false }
  let(:bill_fixed_charges_monthly) { false }
  let(:pay_in_advance) { false }
  let(:interval) { :yearly }
  let(:fixed_charge) { create(:fixed_charge, plan:, pay_in_advance: false) }
  let(:fixed_charge_pay_in_advance) { create(:fixed_charge, :pay_in_advance, plan:) }

  describe "#call" do
    subject(:service_call) { service.call }

    context "when plan is paid in arrears" do
      let(:pay_in_advance) { false }

      context "when plan has no minimum commitment" do
        it "returns result with zero amount cents" do
          expect(service_call.amount_cents).to eq(0)
        end
      end

      context "when plan has minimum commitment" do
        let(:commitment) { create(:commitment, plan:, amount_cents: commitment_amount_cents) }
        let(:commitment_amount_cents) { 200 }

        before { commitment }

        context "when there are no fees" do
          it "returns result with amount cents" do
            expect(service_call.amount_cents).to eq(commitment_amount_cents)
          end
        end

        context "when there are subscription fees" do
          let(:charge) { create(:standard_charge) }

          before do
            create(
              :fee,
              subscription: invoice_subscription.subscription,
              invoice: invoice_subscription.invoice,
              amount_cents: 200
            )

            create(
              :charge_fee,
              subscription: invoice_subscription.subscription,
              invoice: invoice_subscription.invoice,
              charge:,
              amount_cents: 300,
              properties: {
                charges_from_datetime:,
                charges_to_datetime:
              }
            )

            create(
              :fixed_charge_fee,
              subscription: invoice_subscription.subscription,
              invoice: invoice_subscription.invoice,
              fixed_charge:,
              amount_cents: 150,
              properties: {
                fixed_charges_from_datetime:,
                fixed_charges_to_datetime:
              }
            )
          end

          context "when subscription is anniversary" do
            let(:billing_time) { :anniversary }

            context "when plan has yearly interval" do
              let(:interval) { :yearly }
              let(:from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:to_datetime) { DateTime.parse("2024-12-31T23:59:59.999") }
              let(:charges_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:charges_to_datetime) { DateTime.parse("2024-12-31T23:59:59.999") }
              let(:fixed_charges_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:fixed_charges_to_datetime) { DateTime.parse("2024-12-31T23:59:59.999") }
              let(:timestamp) { DateTime.parse("2025-01-01T10:00:00") }

              context "when charges and fixed charges are billed yearly" do
                context "when fees total amount is greater or equal than the commitment amount" do
                  it "returns result with zero amount cents" do
                    expect(service_call.amount_cents).to eq(0)
                  end
                end

                context "when fees total amount is smaller than the commitment amount" do
                  let(:commitment_amount_cents) { 10_000 }

                  context "with an in-advance charge for the next period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime: charges_from_datetime + 1.year,
                          charges_to_datetime: charges_to_datetime + 1.year
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(9_350)
                    end
                  end

                  context "with an in-advance charge for current period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime:,
                          charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end

                  context "with an in-advance charge from another period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(9_350)
                    end
                  end

                  context "with an in-advance fixed charge for the next period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime: fixed_charges_from_datetime + 1.year,
                          fixed_charges_to_datetime: fixed_charges_to_datetime + 1.year
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(9_350)
                    end
                  end

                  context "with an in-advance fixed charge for current period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime:,
                          fixed_charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end

                  context "with an in-advance fixed charge from another period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(9_350)
                    end
                  end
                end
              end

              context "when charges are billed monthly" do
                let(:bill_charges_monthly) { true }
                let(:commitment_amount_cents) { 10_000 }

                let(:invoice_subscription_previous) do
                  create(
                    :invoice_subscription,
                    subscription:,
                    from_datetime: DateTime.parse("2024-01-01T00:00:00"),
                    to_datetime: DateTime.parse("2024-01-31T23:59:59.999"),
                    charges_from_datetime: DateTime.parse("2024-01-01T00:00:00"),
                    charges_to_datetime: DateTime.parse("2024-01-31T23:59:59.999"),
                    fixed_charges_from_datetime: DateTime.parse("2024-01-01T00:00:00"),
                    fixed_charges_to_datetime: DateTime.parse("2024-12-31T23:59:59.999"),
                    timestamp: DateTime.parse("2024-02-01T10:00:00")
                  )
                end

                context "with an in-advance charge for the next period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: invoice_subscription_previous.invoice,
                      subscription: invoice_subscription_previous.subscription,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime: charges_from_datetime + 1.year,
                        charges_to_datetime: charges_to_datetime + 1.year
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance charge for current period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: invoice_subscription_previous.invoice,
                      subscription: invoice_subscription_previous.subscription,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime:,
                        charges_to_datetime:
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance charge from another period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: invoice_subscription_previous.invoice,
                      subscription: invoice_subscription_previous.subscription,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for the next period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: invoice_subscription_previous.invoice,
                      subscription: invoice_subscription_previous.subscription,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime: fixed_charges_from_datetime + 1.year,
                        fixed_charges_to_datetime: fixed_charges_to_datetime + 1.year
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for current period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: invoice_subscription_previous.invoice,
                      subscription: invoice_subscription_previous.subscription,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime:,
                        fixed_charges_to_datetime:
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance fixed charge from another period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: invoice_subscription_previous.invoice,
                      subscription: invoice_subscription_previous.subscription,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end
              end

              context "when fixed charges are billed monthly" do
                let(:bill_fixed_charges_monthly) { true }
                let(:commitment_amount_cents) { 10_000 }

                context "with an in-advance charge for the next period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime: charges_from_datetime + 1.year,
                        charges_to_datetime: charges_to_datetime + 1.year
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance charge for current period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime:,
                        charges_to_datetime:
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance charge from another period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for the next period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime: fixed_charges_from_datetime + 1.year,
                        fixed_charges_to_datetime: fixed_charges_to_datetime + 1.year
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for current period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime:,
                        fixed_charges_to_datetime:
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance fixed charge from another period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end
              end
            end

            context "when plan has semiannual interval" do
              let(:interval) { :semiannual }
              let(:from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:to_datetime) { DateTime.parse("2024-06-30T23:59:59.999") }
              let(:charges_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:charges_to_datetime) { DateTime.parse("2024-06-30T23:59:59.999") }
              let(:fixed_charges_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:fixed_charges_to_datetime) { DateTime.parse("2024-06-30T23:59:59.999") }
              let(:timestamp) { DateTime.parse("2024-07-01T10:00:00") }

              context "when fees total amount is greater or equal than the commitment amount" do
                it "returns result with zero amount cents" do
                  expect(service_call.amount_cents).to eq(0)
                end
              end

              context "when fees total amount is smaller than the commitment amount" do
                let(:commitment_amount_cents) { 10_000 }

                context "with an in-advance charge for the next period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime: charges_from_datetime + 6.months,
                        charges_to_datetime: charges_to_datetime + 6.months
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance charge for current period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime:,
                        charges_to_datetime:
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance charge from another period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for the next period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime: fixed_charges_from_datetime + 6.months,
                        fixed_charges_to_datetime: fixed_charges_to_datetime + 6.months
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for current period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime:,
                        fixed_charges_to_datetime:
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance fixed charge from another period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end
              end
            end

            context "when charges are billed monthly" do
              let(:bill_charges_monthly) { true }
              let(:commitment_amount_cents) { 10_000 }

              let(:invoice_subscription_previous) do
                create(
                  :invoice_subscription,
                  subscription:,
                  from_datetime: DateTime.parse("2024-01-01T00:00:00"),
                  to_datetime: DateTime.parse("2024-01-31T23:59:59.999"),
                  charges_from_datetime: DateTime.parse("2024-01-01T00:00:00"),
                  charges_to_datetime: DateTime.parse("2024-01-31T23:59:59.999"),
                  fixed_charges_from_datetime: DateTime.parse("2024-01-01T00:00:00"),
                  fixed_charges_to_datetime: DateTime.parse("2024-06-30T23:59:59.999"),
                  timestamp: DateTime.parse("2024-07-01T10:00:00")
                )
              end

              context "with an in-advance charge for the next period" do
                before do
                  create(
                    :charge_fee,
                    invoice: invoice_subscription_previous.invoice,
                    subscription: invoice_subscription_previous.subscription,
                    pay_in_advance: true,
                    charge: create(:standard_charge, :pay_in_advance),
                    amount_cents: 500,
                    properties: {
                      charges_from_datetime: charges_from_datetime + 6.months,
                      charges_to_datetime: charges_to_datetime + 6.months
                    }
                  )
                end

                it "returns result with amount cents" do
                  expect(service_call.amount_cents).to eq(9_350)
                end
              end

              context "with an in-advance charge for current period" do
                before do
                  create(
                    :charge_fee,
                    invoice: invoice_subscription_previous.invoice,
                    subscription: invoice_subscription_previous.subscription,
                    pay_in_advance: true,
                    charge: create(:standard_charge, :pay_in_advance),
                    amount_cents: 500,
                    properties: {
                      charges_from_datetime:,
                      charges_to_datetime:
                    }
                  )
                end

                it "returns result with amount cents" do
                  expect(service_call.amount_cents).to eq(8_850)
                end
              end

              context "with an in-advance charge from another period" do
                before do
                  create(
                    :charge_fee,
                    invoice: invoice_subscription_previous.invoice,
                    subscription: invoice_subscription_previous.subscription,
                    pay_in_advance: true,
                    charge: create(:standard_charge, :pay_in_advance),
                    amount_cents: 500
                  )
                end

                it "returns result with amount cents" do
                  expect(service_call.amount_cents).to eq(9_350)
                end
              end

              context "with an in-advance fixed charge for the next period" do
                before do
                  create(
                    :fixed_charge_fee,
                    invoice: invoice_subscription_previous.invoice,
                    subscription: invoice_subscription_previous.subscription,
                    pay_in_advance: true,
                    fixed_charge: fixed_charge_pay_in_advance,
                    amount_cents: 500,
                    properties: {
                      fixed_charges_from_datetime: fixed_charges_from_datetime + 6.months,
                      fixed_charges_to_datetime: fixed_charges_to_datetime + 6.months
                    }
                  )
                end

                it "returns result with amount cents" do
                  expect(service_call.amount_cents).to eq(9_350)
                end
              end

              context "with an in-advance fixed charge for current period" do
                before do
                  create(
                    :fixed_charge_fee,
                    invoice: invoice_subscription_previous.invoice,
                    subscription: invoice_subscription_previous.subscription,
                    pay_in_advance: true,
                    fixed_charge: fixed_charge_pay_in_advance,
                    amount_cents: 500,
                    properties: {
                      fixed_charges_from_datetime:,
                      fixed_charges_to_datetime:
                    }
                  )
                end

                it "returns result with amount cents" do
                  expect(service_call.amount_cents).to eq(8_850)
                end
              end

              context "with an in-advance fixed charge from another period" do
                before do
                  create(
                    :fixed_charge_fee,
                    invoice: invoice_subscription_previous.invoice,
                    subscription: invoice_subscription_previous.subscription,
                    pay_in_advance: true,
                    fixed_charge: fixed_charge_pay_in_advance,
                    amount_cents: 500
                  )
                end

                it "returns result with amount cents" do
                  expect(service_call.amount_cents).to eq(9_350)
                end
              end
            end

            context "when fixed charges are billed monthly" do
              let(:bill_fixed_charges_monthly) { true }
              let(:commitment_amount_cents) { 10_000 }

              context "with an in-advance charge for the next period" do
                before do
                  create(
                    :charge_fee,
                    invoice: nil,
                    subscription:,
                    pay_in_advance: true,
                    charge: create(:standard_charge, :pay_in_advance),
                    amount_cents: 500,
                    properties: {
                      charges_from_datetime: charges_from_datetime + 6.months,
                      charges_to_datetime: charges_to_datetime + 6.months
                    }
                  )
                end

                it "returns result with amount cents" do
                  expect(service_call.amount_cents).to eq(9_350)
                end
              end

              context "with an in-advance charge for current period" do
                before do
                  create(
                    :charge_fee,
                    invoice: nil,
                    subscription:,
                    pay_in_advance: true,
                    charge: create(:standard_charge, :pay_in_advance),
                    amount_cents: 500,
                    properties: {
                      charges_from_datetime:,
                      charges_to_datetime:
                    }
                  )
                end

                it "returns result with amount cents" do
                  expect(service_call.amount_cents).to eq(8_850)
                end
              end

              context "with an in-advance charge from another period" do
                before do
                  create(
                    :charge_fee,
                    invoice: nil,
                    subscription:,
                    pay_in_advance: true,
                    charge: create(:standard_charge, :pay_in_advance),
                    amount_cents: 500
                  )
                end

                it "returns result with amount cents" do
                  expect(service_call.amount_cents).to eq(9_350)
                end
              end

              context "with an in-advance fixed charge for the next period" do
                before do
                  create(
                    :fixed_charge_fee,
                    invoice: nil,
                    subscription:,
                    pay_in_advance: true,
                    fixed_charge: fixed_charge_pay_in_advance,
                    amount_cents: 500,
                    properties: {
                      fixed_charges_from_datetime: fixed_charges_from_datetime + 6.months,
                      fixed_charges_to_datetime: fixed_charges_to_datetime + 6.months
                    }
                  )
                end

                it "returns result with amount cents" do
                  expect(service_call.amount_cents).to eq(9_350)
                end
              end

              context "with an in-advance fixed charge for current period" do
                before do
                  create(
                    :fixed_charge_fee,
                    invoice: nil,
                    subscription:,
                    pay_in_advance: true,
                    fixed_charge: fixed_charge_pay_in_advance,
                    amount_cents: 500,
                    properties: {
                      fixed_charges_from_datetime:,
                      fixed_charges_to_datetime:
                    }
                  )
                end

                it "returns result with amount cents" do
                  expect(service_call.amount_cents).to eq(8_850)
                end
              end

              context "with an in-advance fixed charge from another period" do
                before do
                  create(
                    :fixed_charge_fee,
                    invoice: nil,
                    subscription:,
                    pay_in_advance: true,
                    fixed_charge: fixed_charge_pay_in_advance,
                    amount_cents: 500
                  )
                end

                it "returns result with amount cents" do
                  expect(service_call.amount_cents).to eq(9_350)
                end
              end
            end

            context "when plan has quarterly interval" do
              let(:interval) { :quarterly }
              let(:from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:to_datetime) { DateTime.parse("2024-03-31T23:59:59.999") }
              let(:charges_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:charges_to_datetime) { DateTime.parse("2024-03-31T23:59:59.999") }
              let(:fixed_charges_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:fixed_charges_to_datetime) { DateTime.parse("2024-03-31T23:59:59.999") }
              let(:timestamp) { DateTime.parse("2024-04-01T10:00:00") }

              context "when fees total amount is greater or equal than the commitment amount" do
                it "returns result with zero amount cents" do
                  expect(service_call.amount_cents).to eq(0)
                end
              end

              context "when fees total amount is smaller than the commitment amount" do
                let(:commitment_amount_cents) { 10_000 }

                context "with an in-advance charge for the next period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime: DateTime.parse("2024-04-01T00:00:00"),
                        charges_to_datetime: DateTime.parse("2024-06-30T23:59:59.999")
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance charge for current period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime:,
                        charges_to_datetime:
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance charge from another period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for the next period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime: fixed_charges_from_datetime + 3.months,
                        fixed_charges_to_datetime: fixed_charges_to_datetime + 3.months
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for current period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime:,
                        fixed_charges_to_datetime:
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance fixed charge from another period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end
              end
            end

            context "when plan has monthly interval" do
              let(:interval) { :monthly }
              let(:from_datetime) { DateTime.parse("2024-02-01T00:00:00") }
              let(:to_datetime) { DateTime.parse("2024-02-29T23:59:59.999") }
              let(:charges_from_datetime) { DateTime.parse("2024-02-01T00:00:00") }
              let(:charges_to_datetime) { DateTime.parse("2024-02-29T23:59:59.999") }
              let(:fixed_charges_from_datetime) { DateTime.parse("2024-02-01T00:00:00") }
              let(:fixed_charges_to_datetime) { DateTime.parse("2024-02-29T23:59:59.999") }
              let(:timestamp) { DateTime.parse("2024-03-01T10:00:00") }

              context "when fees total amount is greater or equal than the commitment amount" do
                it "returns result with zero amount cents" do
                  expect(service_call.amount_cents).to eq(0)
                end
              end

              context "when fees total amount is smaller than the commitment amount" do
                let(:commitment_amount_cents) { 10_000 }

                context "with an in-advance charge for the next period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime: DateTime.parse("2024-03-01T00:00:00"),
                        charges_to_datetime: DateTime.parse("2024-03-31T23:59:59.999")
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance charge for current period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime:,
                        charges_to_datetime:
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance charge from another period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for the next period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime: fixed_charges_from_datetime + 1.month,
                        fixed_charges_to_datetime: fixed_charges_to_datetime + 1.month
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for current period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime:,
                        fixed_charges_to_datetime:
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance fixed charge from another period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end
              end
            end

            context "when plan has weekly interval" do
              let(:interval) { :weekly }
              let(:from_datetime) { DateTime.parse("2024-02-05T00:00:00") }
              let(:to_datetime) { DateTime.parse("2024-02-11T23:59:59.999") }
              let(:charges_from_datetime) { DateTime.parse("2024-02-05T00:00:00") }
              let(:charges_to_datetime) { DateTime.parse("2024-02-11T23:59:59.999") }
              let(:fixed_charges_from_datetime) { DateTime.parse("2024-02-05T00:00:00") }
              let(:fixed_charges_to_datetime) { DateTime.parse("2024-02-11T23:59:59.999") }
              let(:timestamp) { DateTime.parse("2024-02-12T10:00:00") }

              context "when fees total amount is greater or equal than the commitment amount" do
                it "returns result with zero amount cents" do
                  expect(service_call.amount_cents).to eq(0)
                end
              end

              context "when fees total amount is smaller than the commitment amount" do
                let(:commitment_amount_cents) { 10_000 }

                context "with an in-advance charge for the next period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime: DateTime.parse("2024-02-12T00:00:00"),
                        charges_to_datetime: DateTime.parse("2024-02-18T23:59:59.999")
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance charge for current period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime:,
                        charges_to_datetime:
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance charge from another period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for the next period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime: fixed_charges_from_datetime + 1.week,
                        fixed_charges_to_datetime: fixed_charges_to_datetime + 1.week
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for current period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime:,
                        fixed_charges_to_datetime:
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance fixed charge from another period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end
              end
            end
          end

          context "when subscription is calendar" do
            let(:billing_time) { :calendar }

            context "when plan has yearly interval" do
              let(:interval) { :yearly }
              let(:from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:to_datetime) { DateTime.parse("2024-12-31T23:59:59.999") }
              let(:charges_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:charges_to_datetime) { DateTime.parse("2024-12-31T23:59:59.999") }
              let(:fixed_charges_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:fixed_charges_to_datetime) { DateTime.parse("2024-12-31T23:59:59.999") }
              let(:timestamp) { DateTime.parse("2025-01-01T10:00:00") }

              context "when charges and fixed charges are billed yearly" do
                context "when fees total amount is greater or equal than the commitment amount" do
                  it "returns result with zero amount cents" do
                    expect(service_call.amount_cents).to eq(0)
                  end
                end

                context "when fees total amount is smaller than the commitment amount" do
                  let(:commitment_amount_cents) { 10_000 }

                  context "with an in-advance charge for the next period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime: charges_from_datetime + 1.year,
                          charges_to_datetime: charges_to_datetime + 1.year
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(9_350)
                    end
                  end

                  context "with an in-advance charge for current period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime:,
                          charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end

                  context "with an in-advance charge from another period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(9_350)
                    end
                  end

                  context "with an in-advance fixed charge for the next period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime: fixed_charges_from_datetime + 1.year,
                          fixed_charges_to_datetime: fixed_charges_to_datetime + 1.year
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(9_350)
                    end
                  end

                  context "with an in-advance fixed charge for current period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime:,
                          fixed_charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end

                  context "with an in-advance fixed charge from another period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(9_350)
                    end
                  end
                end
              end

              context "when charges are billed monthly" do
                let(:bill_charges_monthly) { true }
                let(:commitment_amount_cents) { 10_000 }

                let(:invoice_subscription_previous) do
                  create(
                    :invoice_subscription,
                    subscription:,
                    from_datetime:,
                    to_datetime: DateTime.parse("2024-01-31T23:59:59.999"),
                    charges_from_datetime: DateTime.parse("2024-01-01T00:00:00"),
                    charges_to_datetime: DateTime.parse("2024-01-31T23:59:59.999"),
                    fixed_charges_from_datetime: DateTime.parse("2024-01-01T00:00:00"),
                    fixed_charges_to_datetime: DateTime.parse("2024-01-31T23:59:59.999"),
                    timestamp: DateTime.parse("2024-02-01T10:00:00")
                  )
                end

                before do
                  create(
                    :fee,
                    subscription: invoice_subscription_previous.subscription,
                    invoice: invoice_subscription_previous.invoice
                  )

                  create(
                    :charge_fee,
                    subscription: invoice_subscription_previous.subscription,
                    invoice: invoice_subscription_previous.invoice,
                    charge:,
                    amount_cents: 300,
                    properties: {
                      charges_from_datetime:,
                      charges_to_datetime:
                    }
                  )
                end

                context "when subscription starts at the beginning of the period" do
                  let(:from_datetime) { DateTime.parse("2024-01-01T00:00:00") }

                  context "with an in-advance charge for the next period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime: charges_from_datetime + 1.year,
                          charges_to_datetime: charges_to_datetime + 1.year
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end

                  context "with an in-advance charge for current period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime:,
                          charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_350)
                    end
                  end

                  context "with an in-advance charge from another period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end

                  context "with an in-advance fixed charge for the next period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime: fixed_charges_from_datetime + 1.year,
                          fixed_charges_to_datetime: fixed_charges_to_datetime + 1.year
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end

                  context "with an in-advance fixed charge for current period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime:,
                          fixed_charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_350)
                    end
                  end

                  context "with an in-advance fixed charge from another period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end
                end

                context "when subscription does not start at the beginning of the period" do
                  let(:from_datetime) { DateTime.parse("2024-01-02T00:00:00") }

                  context "with an in-advance charge for the next period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime: charges_from_datetime + 1.year,
                          charges_to_datetime: charges_to_datetime + 1.year
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_823)
                    end
                  end

                  context "with an in-advance charge for current period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime:,
                          charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_323)
                    end
                  end

                  context "with an in-advance charge from another period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_823)
                    end
                  end

                  context "with an in-advance fixed charge for the next period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime: fixed_charges_from_datetime + 1.year,
                          fixed_charges_to_datetime: fixed_charges_to_datetime + 1.year
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_823)
                    end
                  end

                  context "with an in-advance fixed charge for current period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime:,
                          fixed_charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_323)
                    end
                  end

                  context "with an in-advance fixed charge from another period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_823)
                    end
                  end
                end
              end

              context "when fixed charges are billed monthly" do
                let(:bill_fixed_charges_monthly) { true }
                let(:commitment_amount_cents) { 10_000 }

                let(:invoice_subscription_previous) do
                  create(
                    :invoice_subscription,
                    subscription:,
                    from_datetime:,
                    to_datetime: DateTime.parse("2024-01-31T23:59:59.999"),
                    charges_from_datetime: DateTime.parse("2024-01-01T00:00:00"),
                    charges_to_datetime: DateTime.parse("2024-01-31T23:59:59.999"),
                    fixed_charges_from_datetime: DateTime.parse("2024-01-01T00:00:00"),
                    fixed_charges_to_datetime: DateTime.parse("2024-01-31T23:59:59.999"),
                    timestamp: DateTime.parse("2024-02-01T10:00:00")
                  )
                end

                before do
                  create(
                    :fee,
                    subscription: invoice_subscription_previous.subscription,
                    invoice: invoice_subscription_previous.invoice
                  )

                  create(
                    :charge_fee,
                    subscription: invoice_subscription_previous.subscription,
                    invoice: invoice_subscription_previous.invoice,
                    charge:,
                    amount_cents: 300,
                    properties: {
                      charges_from_datetime:,
                      charges_to_datetime:
                    }
                  )
                end

                context "when subscription starts at the beginning of the period" do
                  let(:from_datetime) { DateTime.parse("2024-01-01T00:00:00") }

                  context "with an in-advance charge for the next period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime: charges_from_datetime + 1.year,
                          charges_to_datetime: charges_to_datetime + 1.year
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end

                  context "with an in-advance charge for current period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime:,
                          charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_350)
                    end
                  end

                  context "with an in-advance charge from another period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end

                  context "with an in-advance fixed charge for the next period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime: fixed_charges_from_datetime + 1.year,
                          fixed_charges_to_datetime: fixed_charges_to_datetime + 1.year
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end

                  context "with an in-advance fixed charge for current period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime:,
                          fixed_charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_350)
                    end
                  end

                  context "with an in-advance fixed charge from another period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end
                end

                context "when subscription does not start at the beginning of the period" do
                  let(:from_datetime) { DateTime.parse("2024-01-02T00:00:00") }

                  context "with an in-advance charge for the next period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime: charges_from_datetime + 1.year,
                          charges_to_datetime: charges_to_datetime + 1.year
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_823)
                    end
                  end

                  context "with an in-advance charge for current period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime:,
                          charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_323)
                    end
                  end

                  context "with an in-advance charge from another period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_823)
                    end
                  end

                  context "with an in-advance fixed charge for the next period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime: fixed_charges_from_datetime + 1.year,
                          fixed_charges_to_datetime: fixed_charges_to_datetime + 1.year
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_823)
                    end
                  end

                  context "with an in-advance fixed charge for current period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime:,
                          fixed_charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_323)
                    end
                  end

                  context "with an in-advance fixed charge from another period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_823)
                    end
                  end
                end
              end
            end

            context "when plan has semiannual interval" do
              let(:interval) { :semiannual }
              let(:from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:to_datetime) { DateTime.parse("2024-06-30T23:59:59.999") }
              let(:charges_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:charges_to_datetime) { DateTime.parse("2024-06-30T23:59:59.999") }
              let(:fixed_charges_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:fixed_charges_to_datetime) { DateTime.parse("2024-06-30T23:59:59.999") }
              let(:timestamp) { DateTime.parse("2024-07-01T10:00:00") }

              context "when plan is billed semiannually" do
                context "when fees total amount is greater or equal than the commitment amount" do
                  it "returns result with zero amount cents" do
                    expect(service_call.amount_cents).to eq(0)
                  end
                end

                context "when fees total amount is smaller than the commitment amount" do
                  let(:commitment_amount_cents) { 10_000 }

                  context "with an in-advance charge for the next period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime: charges_from_datetime + 6.months,
                          charges_to_datetime: charges_to_datetime + 6.months
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(9_350)
                    end
                  end

                  context "with an in-advance charge for current period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime:,
                          charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end

                  context "with an in-advance charge from another period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(9_350)
                    end
                  end

                  context "with an in-advance fixed charge for the next period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime: fixed_charges_from_datetime + 6.months,
                          fixed_charges_to_datetime: fixed_charges_to_datetime + 6.months
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(9_350)
                    end
                  end

                  context "with an in-advance fixed charge for current period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime:,
                          fixed_charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end

                  context "with an in-advance fixed charge from another period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(9_350)
                    end
                  end
                end
              end

              context "when charges are billed monthly" do
                let(:bill_charges_monthly) { true }
                let(:commitment_amount_cents) { 10_000 }

                let(:invoice_subscription_previous) do
                  create(
                    :invoice_subscription,
                    subscription:,
                    from_datetime:,
                    to_datetime: DateTime.parse("2024-01-31T23:59:59.999"),
                    charges_from_datetime: DateTime.parse("2024-01-01T00:00:00"),
                    charges_to_datetime: DateTime.parse("2024-01-31T23:59:59.999"),
                    fixed_charges_from_datetime: DateTime.parse("2024-01-01T00:00:00"),
                    fixed_charges_to_datetime: DateTime.parse("2024-01-31T23:59:59.999"),
                    timestamp: DateTime.parse("2024-02-01T10:00:00")
                  )
                end

                before do
                  create(
                    :fee,
                    subscription: invoice_subscription_previous.subscription,
                    invoice: invoice_subscription_previous.invoice
                  )

                  create(
                    :charge_fee,
                    subscription: invoice_subscription_previous.subscription,
                    invoice: invoice_subscription_previous.invoice,
                    charge:,
                    amount_cents: 300,
                    properties: {
                      charges_from_datetime:,
                      charges_to_datetime:
                    }
                  )
                end

                context "when subscription starts at the beginning of the period" do
                  let(:from_datetime) { DateTime.parse("2024-01-01T00:00:00") }

                  context "with an in-advance charge for the next period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime: charges_from_datetime + 6.months,
                          charges_to_datetime: charges_to_datetime + 6.months
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end

                  context "with an in-advance charge for current period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime:,
                          charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_350)
                    end
                  end

                  context "with an in-advance charge from another period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end

                  context "with an in-advance fixed charge for the next period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime: fixed_charges_from_datetime + 6.months,
                          fixed_charges_to_datetime: fixed_charges_to_datetime + 6.months
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end

                  context "with an in-advance fixed charge for current period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime:,
                          fixed_charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_350)
                    end
                  end

                  context "with an in-advance fixed charge from another period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end
                end

                context "when subscription does not start at the beginning of the period" do
                  let(:from_datetime) { DateTime.parse("2024-01-02T00:00:00") }

                  context "with an in-advance charge for the next period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime: charges_from_datetime + 6.months,
                          charges_to_datetime: charges_to_datetime + 6.months
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_795)
                    end
                  end

                  context "with an in-advance charge for current period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime:,
                          charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_295)
                    end
                  end

                  context "with an in-advance charge from another period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_795)
                    end
                  end

                  context "with an in-advance fixed charge for the next period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime: fixed_charges_from_datetime + 6.months,
                          fixed_charges_to_datetime: fixed_charges_to_datetime + 6.months
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_795)
                    end
                  end

                  context "with an in-advance fixed charge for current period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime:,
                          fixed_charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_295)
                    end
                  end

                  context "with an in-advance fixed charge from another period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_795)
                    end
                  end
                end
              end

              context "when fixed charges are billed monthly" do
                let(:bill_fixed_charges_monthly) { true }
                let(:commitment_amount_cents) { 10_000 }

                let(:invoice_subscription_previous) do
                  create(
                    :invoice_subscription,
                    subscription:,
                    from_datetime:,
                    to_datetime: DateTime.parse("2024-01-31T23:59:59.999"),
                    charges_from_datetime: DateTime.parse("2024-01-01T00:00:00"),
                    charges_to_datetime: DateTime.parse("2024-01-31T23:59:59.999"),
                    fixed_charges_from_datetime: DateTime.parse("2024-01-01T00:00:00"),
                    fixed_charges_to_datetime: DateTime.parse("2024-01-31T23:59:59.999"),
                    timestamp: DateTime.parse("2024-02-01T10:00:00")
                  )
                end

                before do
                  create(
                    :fee,
                    subscription: invoice_subscription_previous.subscription,
                    invoice: invoice_subscription_previous.invoice
                  )

                  create(
                    :charge_fee,
                    subscription: invoice_subscription_previous.subscription,
                    invoice: invoice_subscription_previous.invoice,
                    charge:,
                    amount_cents: 300,
                    properties: {
                      charges_from_datetime:,
                      charges_to_datetime:
                    }
                  )
                end

                context "when subscription starts at the beginning of the period" do
                  let(:from_datetime) { DateTime.parse("2024-01-01T00:00:00") }

                  context "with an in-advance charge for the next period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime: charges_from_datetime + 6.months,
                          charges_to_datetime: charges_to_datetime + 6.months
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end

                  context "with an in-advance charge for current period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime:,
                          charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_350)
                    end
                  end

                  context "with an in-advance charge from another period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end

                  context "with an in-advance fixed charge for the next period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime: fixed_charges_from_datetime + 6.months,
                          fixed_charges_to_datetime: fixed_charges_to_datetime + 6.months
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end

                  context "with an in-advance fixed charge for current period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime:,
                          fixed_charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_350)
                    end
                  end

                  context "with an in-advance fixed charge from another period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_850)
                    end
                  end
                end

                context "when subscription does not start at the beginning of the period" do
                  let(:from_datetime) { DateTime.parse("2024-01-02T00:00:00") }

                  context "with an in-advance charge for the next period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime: charges_from_datetime + 6.months,
                          charges_to_datetime: charges_to_datetime + 6.months
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_795)
                    end
                  end

                  context "with an in-advance charge for current period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500,
                        properties: {
                          charges_from_datetime:,
                          charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_295)
                    end
                  end

                  context "with an in-advance charge from another period" do
                    before do
                      create(
                        :charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        charge: create(:standard_charge, :pay_in_advance),
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_795)
                    end
                  end

                  context "with an in-advance fixed charge for the next period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime: fixed_charges_from_datetime + 6.months,
                          fixed_charges_to_datetime: fixed_charges_to_datetime + 6.months
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_795)
                    end
                  end

                  context "with an in-advance fixed charge for current period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500,
                        properties: {
                          fixed_charges_from_datetime:,
                          fixed_charges_to_datetime:
                        }
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_295)
                    end
                  end

                  context "with an in-advance fixed charge from another period" do
                    before do
                      create(
                        :fixed_charge_fee,
                        invoice: nil,
                        subscription:,
                        pay_in_advance: true,
                        fixed_charge: fixed_charge_pay_in_advance,
                        amount_cents: 500
                      )
                    end

                    it "returns result with amount cents" do
                      expect(service_call.amount_cents).to eq(8_795)
                    end
                  end
                end
              end
            end

            context "when plan has quarterly interval" do
              let(:interval) { :quarterly }
              let(:from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:to_datetime) { DateTime.parse("2024-03-31T23:59:59.999") }
              let(:charges_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:charges_to_datetime) { DateTime.parse("2024-03-31T23:59:59.999") }
              let(:fixed_charges_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:fixed_charges_to_datetime) { DateTime.parse("2024-03-31T23:59:59.999") }
              let(:timestamp) { DateTime.parse("2024-04-01T10:00:00") }

              context "when fees total amount is greater or equal than the commitment amount" do
                it "returns result with zero amount cents" do
                  expect(service_call.amount_cents).to eq(0)
                end
              end

              context "when fees total amount is smaller than the commitment amount" do
                let(:commitment_amount_cents) { 10_000 }

                context "with an in-advance charge for the next period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime: DateTime.parse("2024-04-01T00:00:00"),
                        charges_to_datetime: DateTime.parse("2024-06-30T23:59:59.999")
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance charge for current period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime:,
                        charges_to_datetime:
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance charge from another period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for the next period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime: fixed_charges_from_datetime + 3.months,
                        fixed_charges_to_datetime: fixed_charges_to_datetime + 3.months
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for current period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime:,
                        fixed_charges_to_datetime:
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance fixed charge from another period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end
              end
            end

            context "when plan has monthly interval" do
              let(:interval) { :monthly }
              let(:from_datetime) { DateTime.parse("2024-02-01T00:00:00") }
              let(:to_datetime) { DateTime.parse("2024-02-29T23:59:59.999") }
              let(:charges_from_datetime) { DateTime.parse("2024-02-01T00:00:00") }
              let(:charges_to_datetime) { DateTime.parse("2024-02-29T23:59:59.999") }
              let(:fixed_charges_from_datetime) { DateTime.parse("2024-02-01T00:00:00") }
              let(:fixed_charges_to_datetime) { DateTime.parse("2024-02-29T23:59:59.999") }
              let(:timestamp) { DateTime.parse("2024-03-01T10:00:00") }

              context "when fees total amount is greater or equal than the commitment amount" do
                it "returns result with zero amount cents" do
                  expect(service_call.amount_cents).to eq(0)
                end
              end

              context "when fees total amount is smaller than the commitment amount" do
                let(:commitment_amount_cents) { 10_000 }

                context "with an in-advance charge for the next period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime: DateTime.parse("2024-03-01T00:00:00"),
                        charges_to_datetime: DateTime.parse("2024-03-31T23:59:59.999")
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance charge for current period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime:,
                        charges_to_datetime:
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance charge from another period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for the next period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime: DateTime.parse("2024-03-01T00:00:00"),
                        fixed_charges_to_datetime: DateTime.parse("2024-03-31T23:59:59.999")
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for current period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime:,
                        fixed_charges_to_datetime:
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance fixed charge from another period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end
              end
            end

            context "when plan has weekly interval" do
              let(:interval) { :weekly }
              let(:from_datetime) { DateTime.parse("2024-02-05T00:00:00") }
              let(:to_datetime) { DateTime.parse("2024-02-11T23:59:59.999") }
              let(:charges_from_datetime) { DateTime.parse("2024-02-05T00:00:00") }
              let(:charges_to_datetime) { DateTime.parse("2024-02-11T23:59:59.999") }
              let(:fixed_charges_from_datetime) { DateTime.parse("2024-02-05T00:00:00") }
              let(:fixed_charges_to_datetime) { DateTime.parse("2024-02-11T23:59:59.999") }
              let(:timestamp) { DateTime.parse("2024-02-12T10:00:00") }

              context "when fees total amount is greater or equal than the commitment amount" do
                it "returns result with zero amount cents" do
                  expect(service_call.amount_cents).to eq(0)
                end
              end

              context "when fees total amount is smaller than the commitment amount" do
                let(:commitment_amount_cents) { 10_000 }

                context "with an in-advance charge for the next period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime: DateTime.parse("2024-02-12T00:00:00"),
                        charges_to_datetime: DateTime.parse("2024-02-18T23:59:59.999")
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance charge for current period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime:,
                        charges_to_datetime:
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance charge from another period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 500
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for the next period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime: DateTime.parse("2024-02-12T00:00:00"),
                        fixed_charges_to_datetime: DateTime.parse("2024-02-18T23:59:59.999")
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for current period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime:,
                        fixed_charges_to_datetime:
                      }
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance fixed charge from another period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500
                    )
                  end

                  it "returns result with amount cents" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end
              end
            end
          end
        end
      end
    end

    context "when plan is paid in advance" do
      let(:pay_in_advance) { true }

      context "when plan has no minimum commitment" do
        it "returns result with zero amount cents" do
          expect(service_call.amount_cents).to eq(0)
        end
      end

      context "when plan has minimum commitment" do
        let(:commitment) { create(:commitment, plan:, amount_cents: commitment_amount_cents) }
        let(:commitment_amount_cents) { 10_000 }

        before { commitment }

        context "when there is no previous invoice subscription" do
          it "returns result with zero amount cents" do
            expect(service_call.amount_cents).to eq(0)
          end
        end

        context "when subscription is anniversary" do
          let(:billing_time) { :anniversary }

          context "when plan has yearly interval" do
            let(:interval) { :yearly }
            let(:subscription_at) { DateTime.parse("2023-01-01T00:00:00") }

            # Current invoice subscription (2nd year)
            let(:from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
            let(:to_datetime) { DateTime.parse("2024-12-31T23:59:59.999") }
            let(:charges_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
            let(:charges_to_datetime) { DateTime.parse("2024-12-31T23:59:59.999") }
            let(:fixed_charges_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
            let(:fixed_charges_to_datetime) { DateTime.parse("2024-12-31T23:59:59.999") }
            let(:timestamp) { DateTime.parse("2025-01-01T10:00:00") }

            # Previous invoice subscription (1st year) - fees from this period are counted for the true-up
            # For pay-in-advance, this invoice was generated at the START of the period (2023-01-01)
            let(:previous_invoice_subscription) do
              create(
                :invoice_subscription,
                subscription:,
                from_datetime: DateTime.parse("2023-01-01T00:00:00"),
                to_datetime: DateTime.parse("2023-12-31T23:59:59.999"),
                charges_from_datetime: DateTime.parse("2023-01-01T00:00:00"),
                charges_to_datetime: DateTime.parse("2023-12-31T23:59:59.999"),
                fixed_charges_from_datetime: DateTime.parse("2023-01-01T00:00:00"),
                fixed_charges_to_datetime: DateTime.parse("2023-12-31T23:59:59.999"),
                timestamp: DateTime.parse("2023-01-01T10:00:00")
              )
            end

            context "when charges and fixed charges are billed yearly" do
              # For pay-in-advance plans:
              # - Subscription fee is on the PREVIOUS invoice (paid at start of period)
              # - Charge/fixed charge fees (in arrears) are on the CURRENT invoice
              #   (billed when the next period starts)
              before do
                # Subscription fee on previous invoice - this links the previous period
                create(
                  :fee,
                  subscription: previous_invoice_subscription.subscription,
                  invoice: previous_invoice_subscription.invoice,
                  amount_cents: 200,
                  properties: {
                    from_datetime: previous_invoice_subscription.from_datetime,
                    to_datetime: previous_invoice_subscription.to_datetime
                  }
                )
              end

              context "when fees total amount is greater or equal than the commitment amount" do
                before do
                  # Charge fee for previous period - on CURRENT invoice (billed in arrears)
                  create(
                    :charge_fee,
                    subscription:,
                    invoice: invoice_subscription.invoice,
                    charge: create(:standard_charge, plan:),
                    amount_cents: 5000,
                    properties: {
                      charges_from_datetime: previous_invoice_subscription.charges_from_datetime,
                      charges_to_datetime: previous_invoice_subscription.charges_to_datetime
                    }
                  )

                  # Fixed charge fee for previous period - on CURRENT invoice (billed in arrears)
                  create(
                    :fixed_charge_fee,
                    subscription:,
                    invoice: invoice_subscription.invoice,
                    fixed_charge:,
                    amount_cents: 4900,
                    properties: {
                      fixed_charges_from_datetime: previous_invoice_subscription.fixed_charges_from_datetime,
                      fixed_charges_to_datetime: previous_invoice_subscription.fixed_charges_to_datetime
                    }
                  )
                end

                it "returns result with zero amount cents" do
                  # Total fees: 200 (subscription) + 5000 (charge) + 4900 (fixed_charge) = 11_000
                  expect(service_call.amount_cents).to eq(0)
                end
              end

              context "when fees total amount is smaller than the commitment amount" do
                before do
                  # Charge fee for previous period - on CURRENT invoice (billed in arrears)
                  create(
                    :charge_fee,
                    subscription:,
                    invoice: invoice_subscription.invoice,
                    charge: create(:standard_charge, plan:),
                    amount_cents: 300,
                    properties: {
                      charges_from_datetime: previous_invoice_subscription.charges_from_datetime,
                      charges_to_datetime: previous_invoice_subscription.charges_to_datetime
                    }
                  )

                  # Fixed charge fee for previous period - on CURRENT invoice (billed in arrears)
                  create(
                    :fixed_charge_fee,
                    subscription:,
                    invoice: invoice_subscription.invoice,
                    fixed_charge:,
                    amount_cents: 150,
                    properties: {
                      fixed_charges_from_datetime: previous_invoice_subscription.fixed_charges_from_datetime,
                      fixed_charges_to_datetime: previous_invoice_subscription.fixed_charges_to_datetime
                    }
                  )
                end

                # Total fees: 200 (subscription) + 300 (charge) + 150 (fixed_charge) = 650
                # commitment: 10_000, true-up: 10_000 - 650 = 9_350

                context "with an in-advance charge for the next period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance, plan:),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime: charges_from_datetime + 1.year,
                        charges_to_datetime: charges_to_datetime + 1.year
                      }
                    )
                  end

                  it "does not count it" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance charge for the previous period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance, plan:),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime: previous_invoice_subscription.charges_from_datetime,
                        charges_to_datetime: previous_invoice_subscription.charges_to_datetime
                      }
                    )
                  end

                  it "counts it" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance charge from another period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance, plan:),
                      amount_cents: 500
                    )
                  end

                  it "does not count it" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for the next period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime: fixed_charges_from_datetime + 1.year,
                        fixed_charges_to_datetime: fixed_charges_to_datetime + 1.year
                      }
                    )
                  end

                  it "does not count it" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end

                context "with an in-advance fixed charge for the previous period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime: previous_invoice_subscription.fixed_charges_from_datetime,
                        fixed_charges_to_datetime: previous_invoice_subscription.fixed_charges_to_datetime
                      }
                    )
                  end

                  it "counts it" do
                    expect(service_call.amount_cents).to eq(8_850)
                  end
                end

                context "with an in-advance fixed charge from another period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 500
                    )
                  end

                  it "does not count it" do
                    expect(service_call.amount_cents).to eq(9_350)
                  end
                end
              end
            end

            context "when charges are billed monthly" do
              let(:bill_charges_monthly) { true }

              # For monthly charges on yearly plan:
              # - Subscription fee is on the yearly invoice (previous_invoice_subscription)
              # - Charge fees are on monthly invoices throughout the year
              #
              # Since bill_charges_monthly: true, the FetchInvoicesService queries by
              # charges_from_datetime/charges_to_datetime, which are monthly,
              # so it returns the monthly invoices.

              # Create 12 monthly invoice_subscriptions for charges
              let(:monthly_invoice_subscriptions) do
                (1..12).map do |month|
                  start_date = DateTime.parse("2023-#{month.to_s.rjust(2, "0")}-01T00:00:00")
                  end_date = start_date.end_of_month.change(hour: 23, min: 59, sec: 59)

                  create(
                    :invoice_subscription,
                    subscription:,
                    from_datetime: previous_invoice_subscription.from_datetime,
                    to_datetime: previous_invoice_subscription.to_datetime,
                    charges_from_datetime: start_date,
                    charges_to_datetime: end_date,
                    fixed_charges_from_datetime: previous_invoice_subscription.from_datetime,
                    fixed_charges_to_datetime: previous_invoice_subscription.to_datetime,
                    timestamp: (start_date + 1.month).change(hour: 10)
                  )
                end
              end

              before do
                # Subscription fee on previous yearly invoice
                create(
                  :fee,
                  subscription: previous_invoice_subscription.subscription,
                  invoice: previous_invoice_subscription.invoice,
                  amount_cents: 200,
                  properties: {
                    from_datetime: previous_invoice_subscription.from_datetime,
                    to_datetime: previous_invoice_subscription.to_datetime
                  }
                )
              end

              context "when fees total amount is greater or equal than the commitment amount" do
                before do
                  # Create charge fees on each monthly invoice (total: 12 * 900 = 10800)
                  monthly_invoice_subscriptions.each do |monthly_is|
                    create(
                      :charge_fee,
                      subscription:,
                      invoice: monthly_is.invoice,
                      charge: create(:standard_charge, plan:),
                      amount_cents: 900,
                      properties: {
                        charges_from_datetime: monthly_is.charges_from_datetime,
                        charges_to_datetime: monthly_is.charges_to_datetime
                      }
                    )
                  end
                end

                it "returns result with zero amount cents" do
                  # Total fees: 200 (subscription) + 10800 (charges) = 11000
                  expect(service_call.amount_cents).to eq(0)
                end
              end

              context "when fees total amount is smaller than the commitment amount" do
                before do
                  # Create charge fees on each monthly invoice (total: 12 * 50 = 600)
                  monthly_invoice_subscriptions.each do |monthly_is|
                    create(
                      :charge_fee,
                      subscription:,
                      invoice: monthly_is.invoice,
                      charge: create(:standard_charge, plan:),
                      amount_cents: 50,
                      properties: {
                        charges_from_datetime: monthly_is.charges_from_datetime,
                        charges_to_datetime: monthly_is.charges_to_datetime
                      }
                    )
                  end
                end

                # Total fees: 200 (subscription) + 600 (charges) = 800
                # commitment: 10_000, true-up: 10_000 - 800 = 9_200

                it "returns true-up amount" do
                  expect(service_call.amount_cents).to eq(9_200)
                end
              end
            end

            context "when fixed charges are billed monthly" do
              let(:bill_fixed_charges_monthly) { true }

              # For monthly fixed charges on yearly plan (bill_charges_monthly: false):
              # - Subscription fee is on the yearly invoice (previous_invoice_subscription)
              # - Charge fees are billed yearly (on the current invoice)
              # - Fixed charge fees are on monthly invoices throughout the year
              #
              # The invoice_subscriptions have:
              # - charges_from_datetime/charges_to_datetime = YEARLY (full year)
              # - fixed_charges_from_datetime/fixed_charges_to_datetime = MONTHLY (each month)
              #
              # Since bill_fixed_charges_monthly: true, the FetchInvoicesService queries by
              # fixed_charges_from_datetime/fixed_charges_to_datetime which are monthly,
              # so it finds all 12 monthly invoices.

              # Create 12 monthly invoice_subscriptions for fixed charges
              # These have YEARLY charges dates but MONTHLY fixed_charges dates
              let(:monthly_invoice_subscriptions) do
                (1..12).map do |month|
                  fixed_start = DateTime.parse("2023-#{month.to_s.rjust(2, "0")}-01T00:00:00")
                  fixed_end = fixed_start.end_of_month.change(hour: 23, min: 59, sec: 59, usec: 999999)

                  create(
                    :invoice_subscription,
                    subscription:,
                    from_datetime: previous_invoice_subscription.from_datetime,
                    to_datetime: previous_invoice_subscription.to_datetime,
                    # Charges dates are YEARLY (same as the commitment period)
                    charges_from_datetime: previous_invoice_subscription.charges_from_datetime,
                    charges_to_datetime: previous_invoice_subscription.charges_to_datetime,
                    # Fixed charges dates are MONTHLY
                    fixed_charges_from_datetime: fixed_start,
                    fixed_charges_to_datetime: fixed_end,
                    timestamp: (fixed_start + 1.month).change(hour: 10)
                  )
                end
              end

              before do
                # Subscription fee on previous yearly invoice
                create(
                  :fee,
                  subscription: previous_invoice_subscription.subscription,
                  invoice: previous_invoice_subscription.invoice,
                  amount_cents: 200,
                  properties: {
                    from_datetime: previous_invoice_subscription.from_datetime,
                    to_datetime: previous_invoice_subscription.to_datetime
                  }
                )
              end

              context "when fees total amount is greater or equal than the commitment amount" do
                before do
                  # Charge fee on current invoice (billed yearly in arrears)
                  create(
                    :charge_fee,
                    subscription:,
                    invoice: monthly_invoice_subscriptions.last.invoice,
                    charge: create(:standard_charge, plan:),
                    amount_cents: 5000,
                    properties: {
                      charges_from_datetime: previous_invoice_subscription.charges_from_datetime,
                      charges_to_datetime: previous_invoice_subscription.charges_to_datetime
                    }
                  )

                  # Create fixed charge fees on each monthly invoice (total: 12 * 500 = 6000)
                  monthly_invoice_subscriptions.each do |monthly_is|
                    create(
                      :fixed_charge_fee,
                      subscription:,
                      invoice: monthly_is.invoice,
                      fixed_charge:,
                      amount_cents: 500,
                      properties: {
                        fixed_charges_from_datetime: monthly_is.fixed_charges_from_datetime,
                        fixed_charges_to_datetime: monthly_is.fixed_charges_to_datetime
                      }
                    )
                  end
                end

                it "returns result with zero amount cents" do
                  # Total fees: 200 (subscription) + 5000 (charge) + 6000 (fixed_charges) = 11200
                  expect(service_call.amount_cents).to eq(0)
                end
              end

              context "when fees total amount is smaller than the commitment amount" do
                before do
                  # Charge fee on the last monthly invoice
                  create(
                    :charge_fee,
                    subscription:,
                    invoice: monthly_invoice_subscriptions.last.invoice,
                    charge: create(:standard_charge, plan:),
                    amount_cents: 300,
                    properties: {
                      charges_from_datetime: previous_invoice_subscription.charges_from_datetime,
                      charges_to_datetime: previous_invoice_subscription.charges_to_datetime
                    }
                  )

                  # Create fixed charge fees on each monthly invoice (total: 12 * 30 = 360)
                  monthly_invoice_subscriptions.each do |monthly_is|
                    create(
                      :fixed_charge_fee,
                      subscription:,
                      invoice: monthly_is.invoice,
                      fixed_charge:,
                      amount_cents: 30,
                      properties: {
                        fixed_charges_from_datetime: monthly_is.fixed_charges_from_datetime,
                        fixed_charges_to_datetime: monthly_is.fixed_charges_to_datetime
                      }
                    )
                  end
                end

                # Total fees: 200 (subscription) + 300 (charge) + 360 (fixed_charges) = 860
                # commitment: 10_000, true-up: 10_000 - 860 = 9_140

                it "returns true-up amount" do
                  expect(service_call.amount_cents).to eq(9_140)
                end
              end
            end

            context "when charges and fixed charges are billed monthly" do
              let(:bill_charges_monthly) { true }
              let(:bill_fixed_charges_monthly) { true }

              # For both monthly on yearly plan:
              # - Subscription fee is on the yearly invoice (previous_invoice_subscription)
              # - Charge fees are on monthly invoices
              # - Fixed charge fees are on monthly invoices
              #
              # Since bill_charges_monthly: true, the FetchInvoicesService queries by
              # charges_from_datetime/charges_to_datetime which are monthly, so it finds
              # all 12 monthly invoices.
              #
              # Since bill_fixed_charges_monthly: true, the FetchInvoicesService queries by
              # fixed_charges_from_datetime/fixed_charges_to_datetime which are monthly,
              # so it finds all 12 monthly invoices.
              #
              # Both charge_fees and fixed_charge_fees are counted.

              # Create 12 monthly invoice_subscriptions
              let(:monthly_invoice_subscriptions) do
                (1..12).map do |month|
                  start_date = DateTime.parse("2023-#{month.to_s.rjust(2, "0")}-01T00:00:00")
                  end_date = start_date.end_of_month.change(hour: 23, min: 59, sec: 59, usec: 999999)

                  create(
                    :invoice_subscription,
                    subscription:,
                    from_datetime: previous_invoice_subscription.from_datetime,
                    to_datetime: previous_invoice_subscription.to_datetime,
                    charges_from_datetime: start_date,
                    charges_to_datetime: end_date,
                    fixed_charges_from_datetime: start_date,
                    fixed_charges_to_datetime: end_date,
                    timestamp: (start_date + 1.month).change(hour: 10)
                  )
                end
              end

              before do
                # Subscription fee on previous yearly invoice
                create(
                  :fee,
                  subscription: previous_invoice_subscription.subscription,
                  invoice: previous_invoice_subscription.invoice,
                  amount_cents: 200,
                  properties: {
                    from_datetime: previous_invoice_subscription.from_datetime,
                    to_datetime: previous_invoice_subscription.to_datetime
                  }
                )
              end

              context "when fees total amount is greater or equal than the commitment amount" do
                before do
                  # Create fees on each monthly invoice
                  monthly_invoice_subscriptions.each do |monthly_is|
                    create(
                      :charge_fee,
                      subscription:,
                      invoice: monthly_is.invoice,
                      charge: create(:standard_charge, plan:),
                      amount_cents: 500,
                      properties: {
                        charges_from_datetime: monthly_is.charges_from_datetime,
                        charges_to_datetime: monthly_is.charges_to_datetime
                      }
                    )

                    create(
                      :fixed_charge_fee,
                      subscription:,
                      invoice: monthly_is.invoice,
                      fixed_charge:,
                      amount_cents: 400,
                      properties: {
                        fixed_charges_from_datetime: monthly_is.fixed_charges_from_datetime,
                        fixed_charges_to_datetime: monthly_is.fixed_charges_to_datetime
                      }
                    )
                  end
                end

                it "returns result with zero amount cents" do
                  # Total fees: 200 (subscription) + 6000 (charges) + 4800 (fixed_charges) = 11000
                  expect(service_call.amount_cents).to eq(0)
                end
              end

              context "when fees total amount is smaller than the commitment amount" do
                before do
                  # Create fees on each monthly invoice
                  monthly_invoice_subscriptions.each do |monthly_is|
                    create(
                      :charge_fee,
                      subscription:,
                      invoice: monthly_is.invoice,
                      charge: create(:standard_charge, plan:),
                      amount_cents: 40,
                      properties: {
                        charges_from_datetime: monthly_is.charges_from_datetime,
                        charges_to_datetime: monthly_is.charges_to_datetime
                      }
                    )

                    create(
                      :fixed_charge_fee,
                      subscription:,
                      invoice: monthly_is.invoice,
                      fixed_charge:,
                      amount_cents: 20,
                      properties: {
                        fixed_charges_from_datetime: monthly_is.fixed_charges_from_datetime,
                        fixed_charges_to_datetime: monthly_is.fixed_charges_to_datetime
                      }
                    )
                  end
                end

                # Total fees: 200 (subscription) + 480 (charges) + 240 (fixed_charges) = 920
                # commitment: 10_000, true-up: 10_000 - 920 = 9_080

                it "returns true-up amount" do
                  expect(service_call.amount_cents).to eq(9_080)
                end
              end
            end
          end
        end

        context "when subscription is calendar" do
          let(:billing_time) { :calendar }

          context "when plan has yearly interval" do
            let(:interval) { :yearly }
            let(:commitment_amount_cents) { 10_000 }
            let(:subscription_at) { DateTime.parse("2023-03-15T00:00:00") }

            # Year 1 (partial): Mar 15, 2023 - Dec 31, 2023 (subscription started mid-year)
            # Year 2 (full): Jan 1, 2024 - Dec 31, 2024
            # Commitment is evaluated at year 2, looking at year 1's fees

            context "when there is no previous invoice subscription" do
              # First invoice of subscription - no commitment fee should be charged
              let(:from_datetime) { DateTime.parse("2023-03-15T00:00:00") }
              let(:to_datetime) { DateTime.parse("2023-12-31T23:59:59.999") }
              let(:charges_from_datetime) { DateTime.parse("2023-03-15T00:00:00") }
              let(:charges_to_datetime) { DateTime.parse("2023-12-31T23:59:59.999") }
              let(:fixed_charges_from_datetime) { DateTime.parse("2023-03-15T00:00:00") }
              let(:fixed_charges_to_datetime) { DateTime.parse("2023-12-31T23:59:59.999") }
              let(:timestamp) { DateTime.parse("2024-01-01T10:00:00") }

              context "with charge fees" do
                before do
                  create(
                    :charge_fee,
                    invoice: nil,
                    subscription:,
                    pay_in_advance: true,
                    charge: create(:standard_charge, :pay_in_advance),
                    amount_cents: 2000,
                    properties: {
                      charges_from_datetime: invoice_subscription.charges_from_datetime,
                      charges_to_datetime: invoice_subscription.charges_to_datetime
                    }
                  )

                  create(
                    :charge_fee,
                    invoice: nil,
                    subscription:,
                    pay_in_advance: false,
                    charge: create(:standard_charge),
                    amount_cents: 1500,
                    properties: {
                      charges_from_datetime: invoice_subscription.charges_from_datetime,
                      charges_to_datetime: invoice_subscription.charges_to_datetime
                    }
                  )
                end

                it "returns zero (no commitment evaluation on first invoice)" do
                  expect(service_call.amount_cents).to eq(0)
                end
              end

              context "with fixed charge fees" do
                before do
                  create(
                    :fixed_charge_fee,
                    invoice: nil,
                    subscription:,
                    pay_in_advance: true,
                    fixed_charge: fixed_charge_pay_in_advance,
                    amount_cents: 2000,
                    properties: {
                      fixed_charges_from_datetime: invoice_subscription.fixed_charges_from_datetime,
                      fixed_charges_to_datetime: invoice_subscription.fixed_charges_to_datetime
                    }
                  )

                  create(
                    :fixed_charge_fee,
                    invoice: nil,
                    subscription:,
                    pay_in_advance: false,
                    fixed_charge:,
                    amount_cents: 1500,
                    properties: {
                      fixed_charges_from_datetime: invoice_subscription.fixed_charges_from_datetime,
                      fixed_charges_to_datetime: invoice_subscription.fixed_charges_to_datetime
                    }
                  )
                end

                it "returns zero (no commitment evaluation on first invoice)" do
                  expect(service_call.amount_cents).to eq(0)
                end
              end
            end

            context "when there is a previous invoice subscription" do
              # Second invoice - commitment for year 1 is evaluated
              # Previous period (year 1): Mar 15, 2023 - Dec 31, 2023 (292 days out of 365)
              # Current period (year 2): Jan 1, 2024 - Dec 31, 2024

              let(:previous_invoice_subscription) do
                create(
                  :invoice_subscription,
                  subscription:,
                  from_datetime: DateTime.parse("2023-03-15T00:00:00"),
                  to_datetime: DateTime.parse("2023-12-31T23:59:59.999"),
                  charges_from_datetime: DateTime.parse("2023-03-15T00:00:00"),
                  charges_to_datetime: DateTime.parse("2023-12-31T23:59:59.999"),
                  fixed_charges_from_datetime: DateTime.parse("2023-03-15T00:00:00"),
                  fixed_charges_to_datetime: DateTime.parse("2023-12-31T23:59:59.999"),
                  timestamp: DateTime.parse("2023-03-15T10:00:00")
                )
              end

              let(:from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:to_datetime) { DateTime.parse("2024-12-31T23:59:59.999") }
              let(:charges_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:charges_to_datetime) { DateTime.parse("2024-12-31T23:59:59.999") }
              let(:fixed_charges_from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
              let(:fixed_charges_to_datetime) { DateTime.parse("2024-12-31T23:59:59.999") }
              let(:timestamp) { DateTime.parse("2024-01-01T10:00:00") }

              # Proration: 292 days (Mar 15 - Dec 31) / 365 days (full year) = 292/365 ≈ 0.8
              # Prorated commitment: 10000 * 292/365 = 8000

              # Subscription fee on previous invoice (500) - common to all scenarios
              before do
                create(
                  :fee,
                  subscription: previous_invoice_subscription.subscription,
                  invoice: previous_invoice_subscription.invoice,
                  amount_cents: 500,
                  properties: {
                    from_datetime: previous_invoice_subscription.from_datetime,
                    to_datetime: previous_invoice_subscription.to_datetime
                  }
                )
              end

              context "when fees total amount is greater or equal than the prorated commitment" do
                before do
                  # In-advance charge (4000) + arrears charge (4000) = 8000 + 500 sub = 8500 >= 8000
                  create(
                    :charge_fee,
                    invoice: nil,
                    subscription:,
                    pay_in_advance: true,
                    charge: create(:standard_charge, :pay_in_advance),
                    amount_cents: 4000,
                    properties: {
                      charges_from_datetime: previous_invoice_subscription.charges_from_datetime,
                      charges_to_datetime: previous_invoice_subscription.charges_to_datetime
                    }
                  )

                  create(
                    :charge_fee,
                    invoice: invoice_subscription.invoice,
                    subscription:,
                    pay_in_advance: false,
                    charge: create(:standard_charge),
                    amount_cents: 4000,
                    properties: {
                      charges_from_datetime: previous_invoice_subscription.charges_from_datetime,
                      charges_to_datetime: previous_invoice_subscription.charges_to_datetime
                    }
                  )
                end

                it "returns zero" do
                  # fees = 500 (subscription) + 4000 (in-advance) + 4000 (arrears) = 8500 >= 8000
                  expect(service_call.amount_cents).to eq(0)
                end
              end

              context "when fees total amount is smaller than the prorated commitment" do
                before do
                  # In-advance charge (1500) + arrears charge (1000) = 2500 + 500 sub = 3000 < 8000
                  create(
                    :charge_fee,
                    invoice: nil,
                    subscription:,
                    pay_in_advance: true,
                    charge: create(:standard_charge, :pay_in_advance),
                    amount_cents: 1500,
                    properties: {
                      charges_from_datetime: previous_invoice_subscription.charges_from_datetime,
                      charges_to_datetime: previous_invoice_subscription.charges_to_datetime
                    }
                  )

                  create(
                    :charge_fee,
                    invoice: invoice_subscription.invoice,
                    subscription:,
                    pay_in_advance: false,
                    charge: create(:standard_charge),
                    amount_cents: 1000,
                    properties: {
                      charges_from_datetime: previous_invoice_subscription.charges_from_datetime,
                      charges_to_datetime: previous_invoice_subscription.charges_to_datetime
                    }
                  )
                end

                # Base true_up: 8000 - 3000 = 5000

                it "returns true-up amount" do
                  expect(service_call.amount_cents).to eq(5000)
                end

                context "with an in-advance charge for the next period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 1000,
                      properties: {
                        charges_from_datetime: charges_from_datetime + 1.year,
                        charges_to_datetime: charges_to_datetime + 1.year
                      }
                    )
                  end

                  it "does not count it" do
                    expect(service_call.amount_cents).to eq(5000)
                  end
                end

                context "with an in-advance charge for the previous period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 1000,
                      properties: {
                        charges_from_datetime: previous_invoice_subscription.charges_from_datetime,
                        charges_to_datetime: previous_invoice_subscription.charges_to_datetime
                      }
                    )
                  end

                  it "counts it" do
                    # 8000 - (3000 + 1000) = 4000
                    expect(service_call.amount_cents).to eq(4000)
                  end
                end

                context "with an in-advance charge from another period (no dates)" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 1000
                    )
                  end

                  it "does not count it" do
                    expect(service_call.amount_cents).to eq(5000)
                  end
                end

                context "with an in-advance fixed charge for the next period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 1000,
                      properties: {
                        fixed_charges_from_datetime: fixed_charges_from_datetime + 1.year,
                        fixed_charges_to_datetime: fixed_charges_to_datetime + 1.year
                      }
                    )
                  end

                  it "does not count it" do
                    expect(service_call.amount_cents).to eq(5000)
                  end
                end

                context "with an in-advance fixed charge for the previous period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 1000,
                      properties: {
                        fixed_charges_from_datetime: previous_invoice_subscription.fixed_charges_from_datetime,
                        fixed_charges_to_datetime: previous_invoice_subscription.fixed_charges_to_datetime
                      }
                    )
                  end

                  it "counts it" do
                    # 8000 - (3000 + 1000) = 4000
                    expect(service_call.amount_cents).to eq(4000)
                  end
                end

                context "with an in-advance fixed charge from another period (no dates)" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription:,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 1000
                    )
                  end

                  it "does not count it" do
                    expect(service_call.amount_cents).to eq(5000)
                  end
                end
              end

              context "with fixed charge fees only" do
                before do
                  create(
                    :fixed_charge_fee,
                    invoice: nil,
                    subscription:,
                    pay_in_advance: true,
                    fixed_charge: fixed_charge_pay_in_advance,
                    amount_cents: 1500,
                    properties: {
                      fixed_charges_from_datetime: previous_invoice_subscription.fixed_charges_from_datetime,
                      fixed_charges_to_datetime: previous_invoice_subscription.fixed_charges_to_datetime
                    }
                  )

                  create(
                    :fixed_charge_fee,
                    invoice: invoice_subscription.invoice,
                    subscription:,
                    pay_in_advance: false,
                    fixed_charge:,
                    amount_cents: 1000,
                    properties: {
                      fixed_charges_from_datetime: previous_invoice_subscription.fixed_charges_from_datetime,
                      fixed_charges_to_datetime: previous_invoice_subscription.fixed_charges_to_datetime
                    }
                  )
                end

                it "returns true-up amount" do
                  # fees = 500 (subscription) + 1500 (in-advance) + 1000 (arrears) = 3000
                  # true_up = 8000 - 3000 = 5000
                  expect(service_call.amount_cents).to eq(5000)
                end
              end
            end
          end

          context "when plan has weekly interval" do
            let(:interval) { :weekly }
            let(:commitment_amount_cents) { 3_000 }
            let(:subscription_at) { DateTime.parse("2024-01-02T00:00:00") }

            # Week 1 (partial): Jan 2-7 (subscription started Jan 2, not Jan 1)
            # Week 2 (full): Jan 8-14
            # Commitment is evaluated at week 2, looking at week 1's fees

            context "when there is no previous invoice subscription" do
              # First invoice of subscription - no commitment fee should be charged
              let(:from_datetime) { DateTime.parse("2024-01-02T00:00:00") }
              let(:to_datetime) { DateTime.parse("2024-01-07T23:59:59.999") }
              let(:charges_from_datetime) { DateTime.parse("2024-01-02T00:00:00") }
              let(:charges_to_datetime) { DateTime.parse("2024-01-07T23:59:59.999") }
              let(:fixed_charges_from_datetime) { DateTime.parse("2024-01-02T00:00:00") }
              let(:fixed_charges_to_datetime) { DateTime.parse("2024-01-07T23:59:59.999") }
              let(:timestamp) { DateTime.parse("2024-01-08T10:00:00") }

              context "with charge fees" do
                before do
                  create(
                    :charge_fee,
                    invoice: nil,
                    subscription:,
                    pay_in_advance: true,
                    charge: create(:standard_charge, :pay_in_advance),
                    amount_cents: 700,
                    properties: {
                      charges_from_datetime: invoice_subscription.charges_from_datetime,
                      charges_to_datetime: invoice_subscription.charges_to_datetime
                    }
                  )

                  create(
                    :charge_fee,
                    invoice: nil,
                    subscription:,
                    pay_in_advance: false,
                    charge: create(:standard_charge),
                    amount_cents: 500,
                    properties: {
                      charges_from_datetime: invoice_subscription.charges_from_datetime,
                      charges_to_datetime: invoice_subscription.charges_to_datetime
                    }
                  )
                end

                it "returns zero (no commitment evaluation on first invoice)" do
                  expect(service_call.amount_cents).to eq(0)
                end
              end

              context "with fixed charge fees" do
                before do
                  create(
                    :fixed_charge_fee,
                    invoice: nil,
                    subscription:,
                    pay_in_advance: true,
                    fixed_charge: fixed_charge_pay_in_advance,
                    amount_cents: 700,
                    properties: {
                      fixed_charges_from_datetime: invoice_subscription.fixed_charges_from_datetime,
                      fixed_charges_to_datetime: invoice_subscription.fixed_charges_to_datetime
                    }
                  )

                  create(
                    :fixed_charge_fee,
                    invoice: nil,
                    subscription:,
                    pay_in_advance: false,
                    fixed_charge:,
                    amount_cents: 500,
                    properties: {
                      fixed_charges_from_datetime: invoice_subscription.fixed_charges_from_datetime,
                      fixed_charges_to_datetime: invoice_subscription.fixed_charges_to_datetime
                    }
                  )
                end

                it "returns zero (no commitment evaluation on first invoice)" do
                  expect(service_call.amount_cents).to eq(0)
                end
              end
            end

            context "when there is a previous invoice subscription" do
              # Second invoice - commitment for week 1 is evaluated
              # Previous period (week 1): Jan 2-7 (6 days out of 7-day week)
              # Current period (week 2): Jan 8-14

              let(:previous_invoice_subscription) do
                create(
                  :invoice_subscription,
                  subscription:,
                  from_datetime: DateTime.parse("2024-01-02T00:00:00"),
                  to_datetime: DateTime.parse("2024-01-07T23:59:59.999"),
                  charges_from_datetime: DateTime.parse("2024-01-02T00:00:00"),
                  charges_to_datetime: DateTime.parse("2024-01-07T23:59:59.999"),
                  fixed_charges_from_datetime: DateTime.parse("2024-01-02T00:00:00"),
                  fixed_charges_to_datetime: DateTime.parse("2024-01-07T23:59:59.999"),
                  timestamp: DateTime.parse("2024-01-02T10:00:00")
                )
              end

              let(:from_datetime) { DateTime.parse("2024-01-08T00:00:00") }
              let(:to_datetime) { DateTime.parse("2024-01-14T23:59:59.999") }
              let(:charges_from_datetime) { DateTime.parse("2024-01-08T00:00:00") }
              let(:charges_to_datetime) { DateTime.parse("2024-01-14T23:59:59.999") }
              let(:fixed_charges_from_datetime) { DateTime.parse("2024-01-08T00:00:00") }
              let(:fixed_charges_to_datetime) { DateTime.parse("2024-01-14T23:59:59.999") }
              let(:timestamp) { DateTime.parse("2024-01-08T10:00:00") }

              # Proration: 6 days (Jan 2-7) / 7 days (full week) = 6/7
              # Prorated commitment: 3000 * 6/7 = 2571

              # Subscription fee on previous invoice (200) - common to all scenarios
              before do
                create(
                  :fee,
                  subscription: previous_invoice_subscription.subscription,
                  invoice: previous_invoice_subscription.invoice,
                  amount_cents: 200,
                  properties: {
                    from_datetime: previous_invoice_subscription.from_datetime,
                    to_datetime: previous_invoice_subscription.to_datetime
                  }
                )
              end

              context "when fees total amount is greater or equal than the prorated commitment" do
                before do
                  # In-advance charge (1500) + arrears charge (1000) = 2500 + 200 sub = 2700 >= 2571
                  create(
                    :charge_fee,
                    invoice: nil,
                    subscription:,
                    pay_in_advance: true,
                    charge: create(:standard_charge, :pay_in_advance),
                    amount_cents: 1500,
                    properties: {
                      charges_from_datetime: previous_invoice_subscription.charges_from_datetime,
                      charges_to_datetime: previous_invoice_subscription.charges_to_datetime
                    }
                  )

                  create(
                    :charge_fee,
                    invoice: invoice_subscription.invoice,
                    subscription:,
                    pay_in_advance: false,
                    charge: create(:standard_charge),
                    amount_cents: 1000,
                    properties: {
                      charges_from_datetime: previous_invoice_subscription.charges_from_datetime,
                      charges_to_datetime: previous_invoice_subscription.charges_to_datetime
                    }
                  )
                end

                it "returns zero" do
                  # fees = 200 (subscription) + 1500 (in-advance) + 1000 (arrears) = 2700 >= 2571
                  expect(service_call.amount_cents).to eq(0)
                end
              end

              context "when fees total amount is smaller than the prorated commitment" do
                before do
                  # In-advance charge (700) + arrears charge (500) = 1200 + 200 sub = 1400 < 2571
                  create(
                    :charge_fee,
                    invoice: nil,
                    subscription: subscription,
                    pay_in_advance: true,
                    charge: create(:standard_charge, :pay_in_advance),
                    amount_cents: 700,
                    properties: {
                      charges_from_datetime: previous_invoice_subscription.charges_from_datetime,
                      charges_to_datetime: previous_invoice_subscription.charges_to_datetime
                    }
                  )

                  create(
                    :charge_fee,
                    invoice: invoice_subscription.invoice,
                    subscription: subscription,
                    pay_in_advance: false,
                    charge: create(:standard_charge),
                    amount_cents: 500,
                    properties: {
                      charges_from_datetime: previous_invoice_subscription.charges_from_datetime,
                      charges_to_datetime: previous_invoice_subscription.charges_to_datetime
                    }
                  )
                end

                # Base true_up: 2571 - 1400 = 1171

                it "returns true-up amount" do
                  expect(service_call.amount_cents).to eq(1171)
                end

                context "with an in-advance charge for the next period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription: subscription,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 300,
                      properties: {
                        charges_from_datetime: charges_from_datetime + 1.week,
                        charges_to_datetime: charges_to_datetime + 1.week
                      }
                    )
                  end

                  it "does not count it" do
                    expect(service_call.amount_cents).to eq(1171)
                  end
                end

                context "with an in-advance charge for the previous period" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription: subscription,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 300,
                      properties: {
                        charges_from_datetime: previous_invoice_subscription.charges_from_datetime,
                        charges_to_datetime: previous_invoice_subscription.charges_to_datetime
                      }
                    )
                  end

                  it "counts it" do
                    # 2571 - (1400 + 300) = 871
                    expect(service_call.amount_cents).to eq(871)
                  end
                end

                context "with an in-advance charge from another period (no dates)" do
                  before do
                    create(
                      :charge_fee,
                      invoice: nil,
                      subscription: subscription,
                      pay_in_advance: true,
                      charge: create(:standard_charge, :pay_in_advance),
                      amount_cents: 300
                    )
                  end

                  it "does not count it" do
                    expect(service_call.amount_cents).to eq(1171)
                  end
                end

                context "with an in-advance fixed charge for the next period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription: subscription,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 300,
                      properties: {
                        fixed_charges_from_datetime: fixed_charges_from_datetime + 1.week,
                        fixed_charges_to_datetime: fixed_charges_to_datetime + 1.week
                      }
                    )
                  end

                  it "does not count it" do
                    expect(service_call.amount_cents).to eq(1171)
                  end
                end

                context "with an in-advance fixed charge for the previous period" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription: subscription,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 300,
                      properties: {
                        fixed_charges_from_datetime: previous_invoice_subscription.fixed_charges_from_datetime,
                        fixed_charges_to_datetime: previous_invoice_subscription.fixed_charges_to_datetime
                      }
                    )
                  end

                  it "counts it" do
                    # 2571 - (1400 + 300) = 871
                    expect(service_call.amount_cents).to eq(871)
                  end
                end

                context "with an in-advance fixed charge from another period (no dates)" do
                  before do
                    create(
                      :fixed_charge_fee,
                      invoice: nil,
                      subscription: subscription,
                      pay_in_advance: true,
                      fixed_charge: fixed_charge_pay_in_advance,
                      amount_cents: 300
                    )
                  end

                  it "does not count it" do
                    expect(service_call.amount_cents).to eq(1171)
                  end
                end
              end

              context "with fixed charge fees only" do
                before do
                  create(
                    :fixed_charge_fee,
                    invoice: nil,
                    subscription: subscription,
                    pay_in_advance: true,
                    fixed_charge: fixed_charge_pay_in_advance,
                    amount_cents: 700,
                    properties: {
                      fixed_charges_from_datetime: previous_invoice_subscription.fixed_charges_from_datetime,
                      fixed_charges_to_datetime: previous_invoice_subscription.fixed_charges_to_datetime
                    }
                  )

                  create(
                    :fixed_charge_fee,
                    invoice: invoice_subscription.invoice,
                    subscription: subscription,
                    pay_in_advance: false,
                    fixed_charge: fixed_charge,
                    amount_cents: 500,
                    properties: {
                      fixed_charges_from_datetime: previous_invoice_subscription.fixed_charges_from_datetime,
                      fixed_charges_to_datetime: previous_invoice_subscription.fixed_charges_to_datetime
                    }
                  )
                end

                it "returns true-up amount" do
                  # fees = 200 (subscription) + 700 (in-advance) + 500 (arrears) = 1400
                  # true_up = 2571 - 1400 = 1171
                  expect(service_call.amount_cents).to eq(1171)
                end
              end
            end
          end
        end
      end
    end
  end
end
