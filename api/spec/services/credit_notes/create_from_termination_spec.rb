# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNotes::CreateFromTermination do
  subject(:create_service) { described_class.new(subscription:, context:, **kwargs) }

  let(:kwargs) { {} }

  let(:started_at) { Time.zone.parse("2022-09-01 10:00") }
  let(:subscription_at) { Time.zone.parse("2022-09-01 10:00") }
  let(:terminated_at) { Time.zone.parse("2022-10-15 10:00") }

  let(:customer) { create(:customer, **(customer_timezone ? {timezone: customer_timezone} : {})) }
  let(:customer_timezone) { nil }
  let(:organization) { customer.organization }
  let(:context) { nil }

  let(:subscription) do
    create(
      :subscription,
      customer:,
      plan:,
      status: :terminated,
      subscription_at:,
      started_at:,
      terminated_at:,
      billing_time: :calendar
    )
  end
  let(:plan) do
    create(
      :plan,
      :pay_in_advance,
      organization:,
      amount_cents: plan_amount_cents,
      **(trial_period ? {trial_period:} : {})
    )
  end
  let(:plan_amount_cents) { 31_00 }
  let(:trial_period) { nil }
  let(:tax) { create(:tax, organization:, rate: tax_rate) }
  let(:tax_rate) { 20 }
  let(:coupon_amount) { 0 }

  let(:fee_and_invoice) { generate_invoice_and_fee(plan_amount_cents) }
  let(:invoice) { fee_and_invoice[:invoice] }
  let(:subscription_fee) { fee_and_invoice[:subscription_fee] }
  let(:invoice_applied_tax) { fee_and_invoice[:invoice_applied_tax] }
  let(:paid_amount) { 0 }

  before { fee_and_invoice }

  def generate_invoice(fees_amount_cents:, coupons_amount_cents:, at:)
    amount_after_coupons = fees_amount_cents - coupons_amount_cents
    invoice_taxes_amount_cents = (amount_after_coupons * tax.rate / 100).round
    sub_total_including_taxes_amount_cents = amount_after_coupons + invoice_taxes_amount_cents
    total_amount_cents = sub_total_including_taxes_amount_cents
    invoice = create(
      :invoice,
      organization:,
      customer:,
      currency: "EUR",
      coupons_amount_cents:,
      sub_total_excluding_taxes_amount_cents: amount_after_coupons,
      sub_total_including_taxes_amount_cents: sub_total_including_taxes_amount_cents,
      fees_amount_cents:,
      total_amount_cents: total_amount_cents,
      total_paid_amount_cents: paid_amount,
      payment_status: ((paid_amount == total_amount_cents) ? :succeeded : :pending),
      created_at: at
    )
    create(:invoice_applied_tax, invoice:, tax:, tax_rate: tax.rate, amount_cents: invoice_taxes_amount_cents)

    invoice
  end

  def generate_subscription_fee(invoice:, amount_cents:, coupons_amount_cents:, at:, plan_amount_cents:)
    taxes_amount_cents = (amount_cents - coupons_amount_cents) * tax.rate / 100
    subscription_fee = create(
      :fee,
      subscription:,
      invoice:,
      amount_cents:,
      taxes_amount_cents: taxes_amount_cents,
      precise_amount_cents: amount_cents,
      precise_coupons_amount_cents: coupons_amount_cents,
      taxes_precise_amount_cents: taxes_amount_cents,
      taxes_rate: tax.rate,
      created_at: at,
      **(plan_amount_cents ? {amount_details: {plan_amount_cents:}} : {})
    )
    create(:fee_applied_tax, tax:, fee: subscription_fee, amount_cents: taxes_amount_cents)
    subscription_fee
  end

  def generate_second_subscription_fee(invoice:, amount_cents:, at:)
    second_subscription = create(:subscription, customer:, plan:, subscription_at:, started_at:, billing_time: :calendar)
    second_taxes_amount_cents = (amount_cents * tax.rate / 100).round
    second_subscription_fee = create(:fee,
      subscription: second_subscription,
      invoice:,
      amount_cents: amount_cents,
      taxes_amount_cents: second_taxes_amount_cents,
      precise_amount_cents: amount_cents,
      taxes_precise_amount_cents: second_taxes_amount_cents,
      created_at: at)
    create(:fee_applied_tax, tax:, fee: second_subscription_fee, amount_cents: second_taxes_amount_cents)
  end

  def generate_invoice_and_fee(amount_cents, coupons_amount_cents: coupon_amount, at: started_at, plan_amount_cents: nil, with_second_subscription: false)
    fees_amount_cents = with_second_subscription ? amount_cents * 2 : amount_cents
    invoice = generate_invoice(fees_amount_cents: fees_amount_cents, coupons_amount_cents:, at:)
    subscription_fee = generate_subscription_fee(invoice:, amount_cents:, coupons_amount_cents:, at:, plan_amount_cents:)
    generate_second_subscription_fee(invoice:, amount_cents:, at:) if with_second_subscription

    {
      subscription_fee:,
      invoice:
    }
  end

  def expect_credit_note_to_be_properly_defined(
    credit_note,
    precise_item_amount_cents:,
    total_amount_cents:,
    tax_amount_cents:,
    refund_amount_cents:,
    credit_amount_cents:,
    offset_amount_cents:,
    fee:
  )
    expect(credit_note).to be_available
    expect(credit_note).to be_order_change

    expect(credit_note.total_amount_cents).to eq(total_amount_cents)
    expect(credit_note.total_amount_currency).to eq("EUR")
    expect(credit_note.refund_amount_cents).to eq(refund_amount_cents)
    expect(credit_note.refund_amount_currency).to eq("EUR")
    expect(credit_note.credit_amount_cents).to eq(credit_amount_cents)
    expect(credit_note.credit_amount_currency).to eq("EUR")
    expect(credit_note.offset_amount_cents).to eq(offset_amount_cents)
    expect(credit_note.offset_amount_currency).to eq("EUR")
    expect(credit_note.taxes_amount_cents).to eq(tax_amount_cents)
    expect(credit_note.balance_amount_cents).to eq(credit_amount_cents)
    expect(credit_note.balance_amount_currency).to eq("EUR")
    expect(credit_note.applied_taxes.length).to eq(1)
    expect(credit_note.applied_taxes.first.tax_code).to eq(tax.code)

    expect(credit_note.items.size).to eq(1)

    credit_note_item = credit_note.items.sole
    expect(credit_note_item.fee).to eq(fee)
    expect(credit_note_item.organization).to eq(organization)
    expect(credit_note_item.amount_cents).to eq(precise_item_amount_cents.round)
    expect(credit_note_item.precise_amount_cents).to eq(precise_item_amount_cents)
    expect(credit_note_item.amount_currency).to eq("EUR")
  end

  def test_credit_note_creation_from_termination(expectations:)
    total_amount_cents = expectations.fetch(:total_amount_cents)
    precise_item_amount_cents = expectations.fetch(:precise_item_amount_cents)
    tax_amount_cents = expectations.fetch(:tax_amount_cents)
    refund_amount_cents = expectations.fetch(:refund_amount_cents, 0)
    credit_amount_cents = expectations.fetch(:credit_amount_cents, 0)
    offset_amount_cents = expectations.fetch(:offset_amount_cents, 0)
    fee = expectations.fetch(:fee, subscription_fee)

    refund_amount_cents ||= 0
    fee ||= subscription_fee

    result = create_service.call

    expect(result).to be_success
    expect(result).to be_a(CreditNotes::CreateService::Result)

    credit_note = result.credit_note

    expect_credit_note_to_be_properly_defined(
      credit_note,
      total_amount_cents:,
      precise_item_amount_cents:,
      tax_amount_cents:,
      refund_amount_cents:,
      credit_amount_cents:,
      offset_amount_cents:,
      fee:
    )

    credit_note
  end

  describe "#call" do
    it "creates a credit note" do
      # CREDITABLE AMOUNT CALCULATION
      # Unused subscription (16 days)    €16.00
      #                                  ------
      # Subtotal                         €16.00
      # Tax (20%)                        €3.20
      #                                  ------
      # Total creditable                 €19.20

      test_credit_note_creation_from_termination(expectations: {
        total_amount_cents: 19_20,
        credit_amount_cents: 19_20,
        precise_item_amount_cents: 16_00,
        tax_amount_cents: 3_20
      })
    end

    context "with amount details attached to the fee" do
      let(:fee_and_invoice) { generate_invoice_and_fee(62_00, plan_amount_cents: 62_00) }

      it "creates a credit note based on the amount details" do
        # CREDITABLE AMOUNT CALCULATION
        # Unused subscription (16 days)    €32.00  (16 × €2.00/day)
        #                                  ------
        # Subtotal                         €32.00
        # Tax (20%)                        €6.40
        #                                  ------
        # Total creditable                 €38.40

        test_credit_note_creation_from_termination(expectations: {
          total_amount_cents: 38_40,
          credit_amount_cents: 38_40,
          precise_item_amount_cents: 32_00,
          tax_amount_cents: 6_40
        })
      end
    end

    context "when refund is requested" do
      subject(:create_service) { described_class.new(subscription:, on_termination: :refund, context:) }

      let(:fee_and_invoice) { generate_invoice_and_fee(plan_amount_cents, with_second_subscription: true) }

      context "when invoice is fully paid" do
        let(:paid_amount) { 7440 }

        it "creates a credit note with refund for full amount" do
          # CREDITABLE AMOUNT CALCULATION
          # Unused subscription (16 days)    €16.00
          #                                  ------
          # Subtotal                         €16.00
          # Tax (20%)                        €3.20
          #                                  ------
          # Total creditable                 €19.20
          #
          # REFUND CALCULATION
          # Invoice total paid               €74.40
          # Subscription portion (50%)       €37.20
          #
          # Used subscription (15 days)      €15.00
          #                                  ------
          # Used subtotal                    €15.00
          # Tax (20%)                        €3.00
          #                                  ------
          # Total used                       €18.00
          #
          # Available for refund             €19.20  (€37.20 - €18.00)
          #
          # FINAL AMOUNTS
          # Refund amount                    €19.20
          # Credit amount                    €0.00   (€19.20 - €19.20)
          #                                  ------
          # Total credit note                €19.20

          test_credit_note_creation_from_termination(expectations: {
            total_amount_cents: 19_20,
            precise_item_amount_cents: 16_00,
            tax_amount_cents: 3_20,
            refund_amount_cents: 19_20,
            credit_amount_cents: 0,
            fee: subscription_fee
          })
        end
      end

      context "when invoice is partially paid" do
        context "when payment covers the subscription fee" do
          let(:paid_amount) { 55_80 }

          it "creates a credit note with refund and credit" do
            # CREDITABLE AMOUNT CALCULATION
            # Unused subscription (16 days)    €16.00
            #                                  ------
            # Subtotal                         €16.00
            # Tax (20%)                        €3.20
            #                                  ------
            # Total creditable                 €19.20
            #
            # REFUND CALCULATION
            # Invoice total paid               €55.80
            # Subscription portion (50%)       €27.90
            #
            # Used subscription (15 days)      €15.00
            #                                  ------
            # Used subtotal                    €15.00
            # Tax (20%)                        €3.00
            #                                  ------
            # Total used                       €18.00
            #
            # Available for refund             €9.90   (€27.90 - €18.00)
            #
            # FINAL AMOUNTS
            # Refund amount                    €9.90
            # Credit amount                    €9.30   (€19.20 - €9.90)
            #                                  ------
            # Total credit note                €19.20

            test_credit_note_creation_from_termination(expectations: {
              total_amount_cents: 19_20,
              precise_item_amount_cents: 16_00,
              tax_amount_cents: 3_20,
              refund_amount_cents: 9_90,
              credit_amount_cents: 9_30,
              fee: subscription_fee
            })
          end
        end

        context "when payment does not cover the subscription fee" do
          let(:paid_amount) { 9_30 }

          it "creates a credit note without refund" do
            # CREDITABLE AMOUNT CALCULATION
            # Unused subscription (16 days)    €16.00
            #                                  ------
            # Subtotal                         €16.00
            # Tax (20%)                        €3.20
            #                                  ------
            # Total creditable                 €19.20
            #
            # REFUND CALCULATION
            # Invoice total paid               €9.30
            # Subscription portion (50%)       €4.65
            #
            # Used subscription (15 days)      €15.00
            #                                  ------
            # Used subtotal                    €15.00
            # Tax (20%)                        €3.00
            #                                  ------
            # Total used                       €18.00
            #
            # Available for refund             €0.00   (€4.65 - €18.00, min 0)
            #
            # FINAL AMOUNTS
            # Refund amount                    €0.00
            # Credit amount                    €19.20  (€19.20 - €0.00)
            #                                  ------
            # Total credit note                €19.20

            test_credit_note_creation_from_termination(expectations: {
              total_amount_cents: 19_20,
              precise_item_amount_cents: 16_00,
              tax_amount_cents: 3_20,
              refund_amount_cents: 0,
              credit_amount_cents: 19_20,
              fee: subscription_fee
            })
          end
        end

        context "when there are credit notes on the fee" do
          let(:paid_amount) { 55_80 }
          let(:credit_note) do
            create(:credit_note, customer:, invoice:, credit_amount_cents: 2_00, taxes_amount_cents: 40, refund_amount_cents: 0)
          end
          let(:credit_note_item) do
            create(:credit_note_item, credit_note:,
              fee: subscription_fee, amount_cents: 2_00, precise_amount_cents: 2_00)
          end

          before { credit_note_item }

          context "when there are no coupons" do
            it "creates a credit note with refund and credit" do
              # CREDITABLE AMOUNT CALCULATION
              # Unused subscription (16 days)    €16.00
              # Previous credit notes            -€2.00
              #                                  ------
              # Subtotal                         €14.00
              # Tax (20%)                        €2.80
              #                                  ------
              # Total creditable                 €16.80
              #
              # REFUND CALCULATION
              # Invoice total paid               €55.80
              # Subscription portion (50%)       €27.90
              #
              # Used subscription (15 days)      €15.00
              #                                  ------
              # Used subtotal                    €15.00
              # Tax (20%)                        €3.00
              #                                  ------
              # Total used                       €18.00
              #
              # Available for refund             €9.90  (€27.90 - €18.00)
              #
              # FINAL AMOUNTS
              # Refund amount                    €9.90
              # Credit amount                    €6.90   (€16.80 - €9.90)
              #                                  ------
              # Total credit note                €16.80

              test_credit_note_creation_from_termination(expectations: {
                total_amount_cents: 16_80,
                precise_item_amount_cents: 14_00,
                tax_amount_cents: 2_80,
                refund_amount_cents: 9_90,
                credit_amount_cents: 6_90,
                fee: subscription_fee
              })
            end
          end

          context "when there are coupons" do
            let(:coupon_amount) { 5_00 }
            let(:fee_and_invoice) do
              generate_invoice_and_fee(
                31_00,
                plan_amount_cents: 31_00,
                coupons_amount_cents: coupon_amount,
                with_second_subscription: true
              )
            end

            it "creates a credit note with refund and credit" do
              # CREDITABLE AMOUNT CALCULATION
              # Unused subscription (16 days)    €16.00
              # Previous credit notes            -€2.00
              #                                  ------
              # Subtotal                         €14.00
              # Coupons (14€/31€ * 5€)           -€2.26
              # Tax (20%)                        €2.35
              #                                  ------
              # Total creditable                 €14.09
              #
              # REFUND CALCULATION
              # Invoice total paid               €55.80
              # Subscription portion (45.61%)    €25.45
              #
              # Used subscription (15 days)      €15.00
              #                                  ------
              # Used subtotal                    €15.00
              # Coupons (15€/31€ * 5€)           -€2.42
              # Tax (20%)                        €2.52
              #                                  ------
              # Total used                       €15.10
              #
              # Available for refund             €10.35  (€25.45 - €15.10)
              #
              # FINAL AMOUNTS
              # Refund amount                    €10.35
              # Credit amount                    €3.74   (€14.09 - €10.35)
              #                                  ------
              # Total credit note                €14.09

              test_credit_note_creation_from_termination(expectations: {
                total_amount_cents: 14_09,
                precise_item_amount_cents: 14_00,
                tax_amount_cents: 2_35,
                refund_amount_cents: 10_35,
                credit_amount_cents: 3_74,
                fee: subscription_fee
              })
            end
          end
        end
      end

      context "when invoice has not been paid" do
        let(:paid_amount) { 0 }

        it "creates a credit note with no refund amount" do
          # CREDITABLE AMOUNT CALCULATION
          # Unused subscription (16 days)    €16.00
          #                                  ------
          # Subtotal                         €16.00
          # Tax (20%)                        €3.20
          #                                  ------
          # Total creditable                 €19.20
          #
          # REFUND CALCULATION
          # Invoice not paid                 €0.00
          #
          # FINAL AMOUNTS
          # Refund amount                    €0.00
          # Credit amount                    €19.20
          #                                  ------
          # Total credit note                €19.20

          test_credit_note_creation_from_termination(expectations: {
            total_amount_cents: 19_20,
            precise_item_amount_cents: 16_00,
            tax_amount_cents: 3_20,
            refund_amount_cents: 0,
            credit_amount_cents: 19_20,
            fee: subscription_fee
          })
        end
      end

      context "when it's an upgrade" do
        subject(:create_service) { described_class.new(subscription:, on_termination: :refund, upgrade: true, context:) }

        it "raises NotImplementedError" do
          expect { create_service.call }.to raise_error(NotImplementedError)
        end
      end

      context "when subscription has trial period" do
        let(:trial_period) { 41 }
        let(:paid_amount) { 19_20 }
        let(:fee_and_invoice) { generate_invoice_and_fee(31_00) }

        it "accounts for trial period in refund calculation" do
          # CREDITABLE AMOUNT CALCULATION
          # Unused subscription (16 days)          €16.00
          #                                        ------
          # Subtotal                               €16.00
          # Tax (20%)                              €3.20
          #                                        ------
          # Total creditable                       €19.20
          #
          # REFUND CALCULATION
          # Invoice total paid                     €19.20
          #
          # Used subscription (4 days after trial) €4.00
          #                                        ------
          # Used subtotal                          €4.00
          # Tax (20%)                              €0.80
          #                                        ------
          # Total used                             €4.80
          #
          # Available for refund                   €14.40   (€19.20 - €4.80)
          #
          # FINAL AMOUNTS
          # Refund amount                          €14.40
          # Credit amount                          €4.80   (€19.20 - €14.40)
          #                                        ------
          # Total credit note                      €19.20
          test_credit_note_creation_from_termination(expectations: {
            total_amount_cents: 19_20,
            precise_item_amount_cents: 16_00,
            tax_amount_cents: 3_20,
            refund_amount_cents: 14_40,
            credit_amount_cents: 4_80,
            fee: subscription_fee
          })
        end
      end
    end

    context "when offset is requested" do
      subject(:create_service) { described_class.new(subscription:, on_termination: :offset, context:) }

      let(:fee_and_invoice) { generate_invoice_and_fee(plan_amount_cents, with_second_subscription: true) }

      context "when invoice is fully paid" do
        let(:paid_amount) { 7440 }

        it "creates a credit note without offset amount" do
          # CREDITABLE AMOUNT CALCULATION
          # Unused subscription (16 days)    €16.00
          #                                  ------
          # Subtotal                         €16.00
          # Tax (20%)                        €3.20
          #                                  ------
          # Total creditable                 €19.20
          #
          # REFUND CALCULATION
          # Invoice total paid               €74.40
          # Subscription portion (50%)       €37.20
          #
          # Used subscription (15 days)      €15.00
          #                                  ------
          # Used subtotal                    €15.00
          # Tax (20%)                        €3.00
          #                                  ------
          # Total used                       €18.00
          #
          # Available for refund             €19.20  (€37.20 - €18.00)
          #
          # FINAL AMOUNTS
          # Refund amount                    €19.20
          # Offset amount                    €0.00   (€19.20 - €19.20)
          #                                  ------
          # Total credit note                €19.20

          test_credit_note_creation_from_termination(expectations: {
            total_amount_cents: 19_20,
            precise_item_amount_cents: 16_00,
            tax_amount_cents: 3_20,
            refund_amount_cents: 19_20,
            offset_amount_cents: 0,
            fee: subscription_fee
          })
        end
      end

      context "when invoice is partially paid" do
        context "when payment covers the subscription fee" do
          let(:paid_amount) { 55_80 }

          it "creates a credit note with refund and credit" do
            # CREDITABLE AMOUNT CALCULATION
            # Unused subscription (16 days)    €16.00
            #                                  ------
            # Subtotal                         €16.00
            # Tax (20%)                        €3.20
            #                                  ------
            # Total creditable                 €19.20
            #
            # REFUND CALCULATION
            # Invoice total paid               €55.80
            # Subscription portion (50%)       €27.90
            #
            # Used subscription (15 days)      €15.00
            #                                  ------
            # Used subtotal                    €15.00
            # Tax (20%)                        €3.00
            #                                  ------
            # Total used                       €18.00
            #
            # Available for refund             €9.90   (€27.90 - €18.00)
            #
            # FINAL AMOUNTS
            # Refund amount                    €9.90
            # Offset amount                    €9.30   (€19.20 - €9.90)
            #                                  ------
            # Total credit note                €19.20

            test_credit_note_creation_from_termination(expectations: {
              total_amount_cents: 19_20,
              precise_item_amount_cents: 16_00,
              tax_amount_cents: 3_20,
              refund_amount_cents: 9_90,
              offset_amount_cents: 9_30,
              fee: subscription_fee
            })
          end
        end

        context "when payment does not cover the subscription fee" do
          let(:paid_amount) { 9_30 }

          it "creates a credit note without refund" do
            # CREDITABLE AMOUNT CALCULATION
            # Unused subscription (16 days)    €16.00
            #                                  ------
            # Subtotal                         €16.00
            # Tax (20%)                        €3.20
            #                                  ------
            # Total creditable                 €19.20
            #
            # REFUND CALCULATION
            # Invoice total paid               €9.30
            # Subscription portion (50%)       €4.65
            #
            # Used subscription (15 days)      €15.00
            #                                  ------
            # Used subtotal                    €15.00
            # Tax (20%)                        €3.00
            #                                  ------
            # Total used                       €18.00
            #
            # Available for refund             €0.00   (€4.65 - €18.00, min 0)
            #
            # FINAL AMOUNTS
            # Refund amount                    €0.00
            # Offset amount                    €19.20  (€19.20 - €0.00)
            #                                  ------
            # Total credit note                €19.20

            test_credit_note_creation_from_termination(expectations: {
              total_amount_cents: 19_20,
              precise_item_amount_cents: 16_00,
              tax_amount_cents: 3_20,
              refund_amount_cents: 0,
              offset_amount_cents: 19_20,
              fee: subscription_fee
            })
          end
        end

        context "when there are credit notes on the fee" do
          let(:paid_amount) { 55_80 }
          let(:credit_note) do
            create(:credit_note, customer:, invoice:, credit_amount_cents: 2_00, taxes_amount_cents: 40, refund_amount_cents: 0)
          end
          let(:credit_note_item) do
            create(:credit_note_item, credit_note:,
              fee: subscription_fee, amount_cents: 2_00, precise_amount_cents: 2_00)
          end

          before { credit_note_item }

          context "when there are no coupons" do
            it "creates a credit note with refund and offset" do
              # CREDITABLE AMOUNT CALCULATION
              # Unused subscription (16 days)    €16.00
              # Previous credit notes            -€2.00
              #                                  ------
              # Subtotal                         €14.00
              # Tax (20%)                        €2.80
              #                                  ------
              # Total creditable                 €16.80
              #
              # REFUND CALCULATION
              # Invoice total paid               €55.80
              # Subscription portion (50%)       €27.90
              #
              # Used subscription (15 days)      €15.00
              #                                  ------
              # Used subtotal                    €15.00
              # Tax (20%)                        €3.00
              #                                  ------
              # Total used                       €18.00
              #
              # Available for refund             €9.90  (€27.90 - €18.00)
              #
              # FINAL AMOUNTS
              # Refund amount                    €9.90
              # Offset amount                    €6.90   (€16.80 - €9.90)
              #                                  ------
              # Total credit note                €16.80

              test_credit_note_creation_from_termination(expectations: {
                total_amount_cents: 16_80,
                precise_item_amount_cents: 14_00,
                tax_amount_cents: 2_80,
                refund_amount_cents: 9_90,
                offset_amount_cents: 6_90,
                fee: subscription_fee
              })
            end
          end

          context "when there are coupons" do
            let(:coupon_amount) { 5_00 }
            let(:fee_and_invoice) do
              generate_invoice_and_fee(
                31_00,
                plan_amount_cents: 31_00,
                coupons_amount_cents: coupon_amount,
                with_second_subscription: true
              )
            end

            it "creates a credit note with refund and offset" do
              # CREDITABLE AMOUNT CALCULATION
              # Unused subscription (16 days)    €16.00
              # Previous credit notes            -€2.00
              #                                  ------
              # Subtotal                         €14.00
              # Coupons (14€/31€ * 5€)           -€2.26
              # Tax (20%)                        €2.35
              #                                  ------
              # Total creditable                 €14.09
              #
              # REFUND CALCULATION
              # Invoice total paid               €55.80
              # Subscription portion (45.61%)    €25.45
              #
              # Used subscription (15 days)      €15.00
              #                                  ------
              # Used subtotal                    €15.00
              # Coupons (15€/31€ * 5€)           -€2.42
              # Tax (20%)                        €2.52
              #                                  ------
              # Total used                       €15.10
              #
              # Available for refund             €10.35  (€25.45 - €15.10)
              #
              # FINAL AMOUNTS
              # Refund amount                    €10.35
              # Offset amount                    €3.74   (€14.09 - €10.35)
              #                                  ------
              # Total credit note                €14.09

              test_credit_note_creation_from_termination(expectations: {
                total_amount_cents: 14_09,
                precise_item_amount_cents: 14_00,
                tax_amount_cents: 2_35,
                refund_amount_cents: 10_35,
                offset_amount_cents: 3_74,
                fee: subscription_fee
              })
            end
          end
        end
      end

      context "when invoice has not been paid" do
        let(:paid_amount) { 0 }

        it "creates a credit note with no refund amount" do
          # CREDITABLE AMOUNT CALCULATION
          # Unused subscription (16 days)    €16.00
          #                                  ------
          # Subtotal                         €16.00
          # Tax (20%)                        €3.20
          #                                  ------
          # Total creditable                 €19.20
          #
          # REFUND CALCULATION
          # Invoice not paid                 €0.00
          #
          # FINAL AMOUNTS
          # Refund amount                    €0.00
          # Offset amount                    €19.20
          #                                  ------
          # Total credit note                €19.20

          test_credit_note_creation_from_termination(expectations: {
            total_amount_cents: 19_20,
            precise_item_amount_cents: 16_00,
            tax_amount_cents: 3_20,
            refund_amount_cents: 0,
            offset_amount_cents: 19_20,
            fee: subscription_fee
          })
        end
      end

      context "when it's an upgrade" do
        subject(:create_service) { described_class.new(subscription:, on_termination: :offset, upgrade: true, context:) }

        it "raises NotImplementedError" do
          expect { create_service.call }.to raise_error(NotImplementedError)
        end
      end

      context "when subscription has trial period" do
        let(:trial_period) { 41 }
        let(:paid_amount) { 19_20 }
        let(:fee_and_invoice) { generate_invoice_and_fee(31_00) }

        it "accounts for trial period in refund and offset calculation" do
          # CREDITABLE AMOUNT CALCULATION
          # Unused subscription (16 days)          €16.00
          #                                        ------
          # Subtotal                               €16.00
          # Tax (20%)                              €3.20
          #                                        ------
          # Total creditable                       €19.20
          #
          # REFUND CALCULATION
          # Invoice total paid                     €19.20
          #
          # Used subscription (4 days after trial) €4.00
          #                                        ------
          # Used subtotal                          €4.00
          # Tax (20%)                              €0.80
          #                                        ------
          # Total used                             €4.80
          #
          # Available for refund                   €14.40   (€19.20 - €4.80)
          #
          # FINAL AMOUNTS
          # Refund amount                          €14.40
          # Offset amount                          €4.80   (€19.20 - €14.40)
          #                                        ------
          # Total credit note                      €19.20
          test_credit_note_creation_from_termination(expectations: {
            total_amount_cents: 19_20,
            precise_item_amount_cents: 16_00,
            tax_amount_cents: 3_20,
            refund_amount_cents: 14_40,
            offset_amount_cents: 4_80,
            fee: subscription_fee
          })
        end
      end
    end

    context "when invoice is voided" do
      before { invoice.void! }

      it "does not create a credit note" do
        expect { create_service.call }.not_to change(CreditNote, :count)
      end
    end

    context "when fee amount is zero" do
      let(:plan_amount_cents) { 0 }

      it "does not create a credit note" do
        expect do
          expect(create_service.call.credit_note).to be_nil
        end.not_to change(CreditNote, :count)
      end
    end

    context "when multiple fees" do
      let(:fee_and_invoice_2) do
        generate_invoice_and_fee(62_00, at: Time.zone.parse("2022-10-01 10:00"), plan_amount_cents: 62_00)
      end
      let(:invoice_2) { fee_and_invoice_2[:invoice] }
      let(:subscription_fee_2) { fee_and_invoice_2[:subscription_fee] }

      before { fee_and_invoice_2 }

      it "takes the last fee as reference" do
        # CREDITABLE AMOUNT CALCULATION
        # Unused subscription (16 days)    €32.00  (16 × €2.00/day)
        #                                  ------
        # Subtotal                         €32.00
        # Tax (20%)                        €6.40
        #                                  ------
        # Total creditable                 €38.40

        test_credit_note_creation_from_termination(expectations: {
          total_amount_cents: 38_40,
          credit_amount_cents: 38_40,
          precise_item_amount_cents: 32_00,
          tax_amount_cents: 6_40,
          fee: subscription_fee_2
        })
      end
    end

    context "when existing credit notes on the fee" do
      let(:credit_note) do
        create(
          :credit_note,
          customer: subscription.customer,
          invoice: subscription_fee.invoice,
          credit_amount_cents: 10_00,
          taxes_amount_cents: 2_00
        )
      end
      let(:credit_note_item) do
        create(:credit_note_item, credit_note:,
          fee: subscription_fee, amount_cents: 10_00, precise_amount_cents: 10_00)
      end

      before { credit_note_item }

      it "takes the remaining creditable amount" do
        # CREDITABLE AMOUNT CALCULATION
        # Unused subscription (16 days)    €16.00
        # Previous credit notes            -€10.00
        #                                  ------
        # Subtotal                         €6.00
        # Tax (20%)                        €1.20
        #                                  ------
        # Total creditable                 €7.20

        test_credit_note_creation_from_termination(expectations: {
          total_amount_cents: 7_20,
          credit_amount_cents: 7_20,
          precise_item_amount_cents: 6_00,
          tax_amount_cents: 1_20
        })
      end
    end

    context "when plan has trial period ending after terminated_at" do
      let(:trial_period) { 46 }

      it "excludes the trial from the credit amount" do
        # CREDITABLE AMOUNT CALCULATION
        # Unused subscription (15 days)    €15.00  (excluding trial)
        #                                  ------
        # Subtotal                         €15.00
        # Tax (20%)                        €3.00
        #                                  ------
        # Total creditable                 €18.00

        test_credit_note_creation_from_termination(expectations: {
          total_amount_cents: 18_00,
          credit_amount_cents: 18_00,
          precise_item_amount_cents: 15_00,
          tax_amount_cents: 3_00
        })
      end

      context "when trial ends after the end of the billing period" do
        let(:trial_period) { 120 }

        it "does not creates a credit note" do
          expect { create_service.call }.not_to change(CreditNote, :count)
        end
      end
    end

    context "when plan has been upgraded" do
      let(:kwargs) { {upgrade: true} }

      it "calculates credit note correctly" do
        # CREDITABLE AMOUNT CALCULATION
        # Unused subscription (17 days)    €17.00  (upgrade calculation)
        #                                  ------
        # Subtotal                         €17.00
        # Tax (20%)                        €3.40
        #                                  ------
        # Total creditable                 €20.40

        test_credit_note_creation_from_termination(expectations: {
          total_amount_cents: 20_40,
          credit_amount_cents: 20_40,
          precise_item_amount_cents: 17_00,
          tax_amount_cents: 3_40
        })
      end
    end

    context "with a different timezone" do
      let(:started_at) { Time.zone.parse("2022-09-01 12:00") }
      let(:terminated_at) { Time.zone.parse("2022-10-15 01:00") }

      context "when timezone shift is UTC -" do
        let(:customer_timezone) { "America/Los_Angeles" }

        it "takes the timezone into account" do
          # CREDITABLE AMOUNT CALCULATION
          # Unused subscription (17 days)    €17.00  (timezone adjusted)
          #                                  ------
          # Subtotal                         €17.00
          # Tax (20%)                        €3.40
          #                                  ------
          # Total creditable                 €20.40

          test_credit_note_creation_from_termination(expectations: {
            total_amount_cents: 20_40,
            credit_amount_cents: 20_40,
            precise_item_amount_cents: 17_00,
            tax_amount_cents: 3_40
          })
        end
      end

      context "when timezone shift is UTC +" do
        let(:customer_timezone) { "Europe/Paris" }

        it "takes the timezone into account" do
          # CREDITABLE AMOUNT CALCULATION
          # Unused subscription (16 days)    €16.00  (timezone adjusted)
          #                                  ------
          # Subtotal                         €16.00
          # Tax (20%)                        €3.20
          #                                  ------
          # Total creditable                 €19.20

          test_credit_note_creation_from_termination(expectations: {
            total_amount_cents: 19_20,
            credit_amount_cents: 19_20,
            precise_item_amount_cents: 16_00,
            tax_amount_cents: 3_20
          })
        end
      end
    end

    context "with rounding at max precision" do
      let(:started_at) { Time.zone.parse("2023-01-30 10:00") }
      let(:subscription_at) { Time.zone.parse("2023-01-30 10:00") }
      let(:terminated_at) { Time.zone.parse("2023-03-14 10:00") }

      let(:subscription) do
        create(
          :subscription,
          plan:,
          customer:,
          status: :terminated,
          subscription_at:,
          started_at:,
          terminated_at:,
          billing_time: :anniversary
        )
      end

      let(:plan_amount_cents) { 99_9 }
      let(:tax_rate) { 0 }

      it "creates a credit note" do
        # CREDITABLE AMOUNT CALCULATION
        # Unused subscription (15 days)    €4.995  (15/30 × €9.99)
        #                                  ------
        # Subtotal                         €4.995
        # Tax (0%)                         €0.00
        #                                  ------
        # Total creditable                 €4.99

        test_credit_note_creation_from_termination(expectations: {
          total_amount_cents: 4_99,
          credit_amount_cents: 4_99,
          precise_item_amount_cents: 4_99.49999,
          tax_amount_cents: 0
        })
      end
    end

    context "when coupon covers the entire fee amount" do
      let(:coupon_amount) { plan_amount_cents }

      it "does not create a credit note" do
        # CREDITABLE AMOUNT CALCULATION
        # Unused subscription (16 days)    €16.00
        # Coupon allocation (16/31)        -€16.00
        #                                  ------
        # Subtotal                         €0.00
        # Tax (20%)                        €0.00
        #                                  ------
        # Total creditable                 €0.00
        #
        # The coupon adjustment equals the full credit amount,
        # resulting in zero amounts. Without the guard clause,
        # this would raise an error in CreateService.

        result = create_service.call

        expect(result).to be_success
        expect(result.credit_note).to be_nil
      end
    end

    context "with a coupon applied to the invoice" do
      let(:coupon_amount) { 10_00 }

      it "takes the coupon into account" do
        # CREDITABLE AMOUNT CALCULATION
        # Unused subscription (16 days)    €16.00
        # Coupon allocation (16/31)        -€5.16
        #                                  ------
        # Subtotal                         €10.84
        # Tax (20%)                        €2.17
        #                                  ------
        # Total creditable                 €13.01

        test_credit_note_creation_from_termination(expectations: {
          total_amount_cents: 13_01,
          credit_amount_cents: 13_01,
          precise_item_amount_cents: 16_00,
          tax_amount_cents: 2_17
        })
      end
    end

    context "when 'preview' context provided" do
      let(:context) { :preview }

      it "builds a credit note" do
        # CREDITABLE AMOUNT CALCULATION
        # Unused subscription (16 days)    €16.00
        #                                  ------
        # Subtotal                         €16.00
        # Tax (20%)                        €3.20
        #                                  ------
        # Total creditable                 €19.20

        credit_note = test_credit_note_creation_from_termination(
          expectations: {
            total_amount_cents: 19_20,
            credit_amount_cents: 19_20,
            precise_item_amount_cents: 16_00,
            tax_amount_cents: 3_20,
            fee: subscription_fee
          }
        )

        expect(credit_note).to be_a(CreditNote).and be_new_record
        expect(credit_note.items).to all be_new_record
      end

      it "does not persist any credit note" do
        expect { create_service.call }.not_to change(CreditNote, :count)
      end

      it "does not persist any credit note item" do
        expect { create_service.call }.not_to change(CreditNoteItem, :count)
      end
    end

    context "when invoice is tax_pending and context is :preview" do
      # NOTE: Real termination is blocked upstream by Subscriptions::TerminateService.
      #       Preview is exempt so the dashboard can still render the credit note;
      #       CreditNotes::CreateService#credit_note_status forces :finalized in that case.
      let(:context) { :preview }

      before { invoice.update!(status: :pending, tax_status: :pending) }

      it "builds a credit note without error" do
        result = create_service.call

        expect(result).to be_success
        expect(result.credit_note).to be_a(CreditNote).and be_new_record
      end
    end
  end
end
