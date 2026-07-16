# frozen_string_literal: true

require "rails_helper"

describe "Create credit note Scenarios", :premium do
  let(:organization) { create(:organization, webhook_url: nil, email_settings: []) }
  let(:customer) { create(:customer, organization:) }

  let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 10) }

  let(:plan1) do
    create(
      :plan,
      organization:,
      interval: :monthly,
      amount_cents: 17_900,
      pay_in_advance: true
    )
  end

  let(:plan2) do
    create(
      :plan,
      organization:,
      interval: :monthly,
      amount_cents: 39_900,
      pay_in_advance: true
    )
  end

  let(:coupon) do
    create(
      :coupon,
      organization:,
      amount_cents: 20_000,
      expiration: :no_expiration,
      coupon_type: :fixed_amount,
      frequency: :forever,
      limited_plans: true
    )
  end

  let(:coupon_target) do
    create(:coupon_plan, coupon:, plan: plan2)
  end

  let(:plan_tax) { create(:tax, organization:, name: "Plan Tax", rate: 10, applied_to_organization: false) }
  let(:plan_applied_tax) { create(:plan_applied_tax, plan: plan2, tax: plan_tax) }
  let(:plan_applied_tax2) { create(:plan_applied_tax, plan: plan2, tax:) }

  before do
    tax
    plan_applied_tax
    plan_applied_tax2
  end

  it "Allows creation of partial credit note" do
    # Creates two subscriptions
    travel_to(Time.zone.parse("2022-12-19T12:00:00")) do
      create_subscription(
        {external_customer_id: customer.external_id,
         external_id: "#{customer.external_id}_1",
         plan_code: plan1.code,
         billing_time: :anniversary}
      )

      create_subscription(
        {external_customer_id: customer.external_id,
         external_id: "#{customer.external_id}_2",
         plan_code: plan2.code,
         billing_time: :anniversary}
      )
    end

    # Apply a coupon to the customer
    travel_to(Time.zone.parse("2023-08-29T12:00:00")) do
      apply_coupon(
        {external_customer_id: customer.external_id,
         coupon_code: coupon_target.coupon.code,
         amount_cents: 250_00}
      )
    end

    # Bill subscription on an anniversary date
    travel_to(Time.zone.parse("2023-10-19T12:00:00")) do
      perform_billing
    end

    invoice = customer.invoices.order(created_at: :desc).first
    expect(invoice.fees_amount_cents).to eq(578_00)
    expect(invoice.coupons_amount_cents).to eq(250_00)
    expect(invoice.taxes_rate).to eq(14.54268)
    expect(invoice.taxes_amount_cents).to eq(47_70)
    expect(invoice.total_amount_cents).to eq(375_70)

    fee1 = invoice.fees.find_by(amount_cents: 179_00)
    expect(fee1.precise_coupons_amount_cents).to eq(0)

    fee2 = invoice.fees.find_by(amount_cents: 399_00)
    expect(fee2.precise_coupons_amount_cents).to eq(250_00)

    travel_to(Time.zone.parse("2023-10-23T12:00:00")) do
      Payments::ManualCreateService.call(
        organization:,
        params: {invoice_id: invoice.id, amount_cents: 12_00, reference: "ref1"}
      )

      # Estimate the credit notes amount on full fees
      estimate_credit_note(
        {invoice_id: invoice.id,
         items: [
           {
             fee_id: fee1.id,
             amount_cents: fee1.amount_cents
           },
           {
             fee_id: fee2.id,
             amount_cents: fee2.amount_cents
           }
         ]}
      )

      estimate = json[:estimated_credit_note]
      expect(estimate[:taxes_amount_cents]).to eq(47_70)
      expect(estimate[:sub_total_excluding_taxes_amount_cents]).to eq(328_00)
      expect(estimate[:max_creditable_amount_cents]).to eq(375_70)
      expect(estimate[:max_refundable_amount_cents]).to eq(12_00)
      expect(estimate[:coupons_adjustment_amount_cents]).to eq(250_00)
      expect(estimate[:taxes_rate]).to eq(14.54268)

      estimate_credit_note(
        {invoice_id: invoice.id,
         items: [
           {
             fee_id: fee2.id,
             amount_cents: 262_60
           }
         ]}
      )

      # Estimate the credit notes amount on one partial fee
      estimate = json[:estimated_credit_note]
      expect(estimate[:taxes_amount_cents]).to eq(19_61)
      expect(estimate[:sub_total_excluding_taxes_amount_cents]).to eq(98_06)
      expect(estimate[:max_creditable_amount_cents]).to eq(117_67)
      expect(estimate[:max_refundable_amount_cents]).to eq(12_00)
      expect(estimate[:coupons_adjustment_amount_cents]).to eq(164_54)
      expect(estimate[:taxes_rate]).to eq(20)

      Payments::ManualCreateService.call(
        organization:,
        params: {invoice_id: invoice.id, amount_cents: 105_67, reference: "ref1"}
      )

      # Emit a credit note on only one fee
      create_credit_note({invoice_id: invoice.id,
         reason: :other,
         credit_amount_cents: 0,
         refund_amount_cents: 117_67,
         items: [
           {
             fee_id: fee2.id,
             amount_cents: 262_60
           }
         ]})
    end

    credit_note = invoice.credit_notes.first
    expect(credit_note).to have_attributes(
      sub_total_excluding_taxes_amount_cents: 98_06,
      taxes_amount_cents: 19_61,
      refund_amount_cents: 117_67,
      total_amount_cents: 117_67,
      coupons_adjustment_amount_cents: 164_54
    )
  end

  context "when applying multiple time the same coupon" do
    let(:plan) do
      create(
        :plan,
        organization:,
        interval: :monthly,
        amount_cents: 1_999,
        pay_in_advance: false
      )
    end

    let(:charge1) do
      create(
        :standard_charge,
        plan:,
        min_amount_cents: 99_290
      )
    end

    let(:charge2) do
      create(
        :standard_charge,
        plan:,
        min_amount_cents: 299_770
      )
    end

    let(:charge3) do
      create(
        :standard_charge,
        plan:,
        min_amount_cents: 3_130
      )
    end

    let(:charge4) do
      create(
        :standard_charge,
        plan:,
        min_amount_cents: 6_460
      )
    end

    let(:charge5) do
      create(
        :standard_charge,
        plan:,
        min_amount_cents: 3_130
      )
    end

    let(:coupon) do
      create(
        :coupon,
        organization:,
        amount_cents: 10_00,
        expiration: :no_expiration,
        coupon_type: :fixed_amount,
        frequency: :forever,
        limited_plans: false,
        reusable: true
      )
    end

    before do
      charge1
      charge2
      charge3
      charge4
      charge5
    end

    it "Allows creation of partial credit note" do
      # Creates two subscriptions
      travel_to(Time.zone.parse("2022-12-19T12:00:00")) do
        create_subscription(
          {external_customer_id: customer.external_id,
           external_id: "#{customer.external_id}_1",
           plan_code: plan.code,
           billing_time: :anniversary}
        )
      end

      # Apply a coupon twice to the customer
      travel_to(Time.zone.parse("2023-08-29")) do
        apply_coupon(
          {external_customer_id: customer.external_id,
           coupon_code: coupon.code,
           amount_cents: 1_000}
        )

        apply_coupon(
          {external_customer_id: customer.external_id,
           coupon_code: coupon.code,
           amount_cents: 1_000}
        )
      end

      # Bill subscription on an anniversary date
      travel_to(Time.zone.parse("2023-10-19")) do
        perform_billing
      end

      invoice = customer.invoices.order(created_at: :desc).first
      expect(invoice.fees_amount_cents).to eq(413_779)
      expect(invoice.coupons_amount_cents).to eq(2_000)
      expect(invoice.taxes_rate).to eq(10)
      expect(invoice.taxes_amount_cents).to eq(41_178)
      expect(invoice.total_amount_cents).to eq(452_957)

      fee1 = invoice.fees.find_by(amount_cents: charge1.min_amount_cents)
      expect(fee1.precise_coupons_amount_cents).to eq(479.91802)

      fee2 = invoice.fees.find_by(amount_cents: charge2.min_amount_cents)
      expect(fee2.precise_coupons_amount_cents).to eq(1_448.93772)

      fee3 = invoice.fees.find_by(amount_cents: charge3.min_amount_cents)
      expect(fee3.precise_coupons_amount_cents).to eq(15.12884)

      fee4 = invoice.fees.find_by(amount_cents: charge4.min_amount_cents)
      expect(fee4.precise_coupons_amount_cents).to eq(31.2244)

      fee5 = invoice.fees.find_by(amount_cents: charge5.min_amount_cents)
      expect(fee5.precise_coupons_amount_cents).to eq(15.12884)

      fee6 = invoice.fees.find_by(amount_cents: plan.amount_cents)
      expect(fee6.precise_coupons_amount_cents).to eq(9.66216)

      travel_to(Time.zone.parse("2023-10-23")) do
        Payments::ManualCreateService.call(
          organization:,
          params: {invoice_id: invoice.id, amount_cents: 40, reference: "ref2"}
        )

        estimate_credit_note({
          invoice_id: invoice.id,
          items: [
            {
              fee_id: fee6.id,
              amount_cents: 100
            },
            {
              fee_id: fee2.id,
              amount_cents: 100
            },
            {
              fee_id: fee3.id,
              amount_cents: 100
            },
            {
              fee_id: fee4.id,
              amount_cents: 100
            },
            {
              fee_id: fee5.id,
              amount_cents: 100
            }
          ]
        })

        estimate = json[:estimated_credit_note]
        expect(estimate[:coupons_adjustment_amount_cents]).to eq(2)
        expect(estimate[:sub_total_excluding_taxes_amount_cents]).to eq(4_98)
        expect(estimate[:taxes_amount_cents]).to eq(49)
        expect(estimate[:max_creditable_amount_cents]).to eq(5_47)
        expect(estimate[:max_refundable_amount_cents]).to eq(40)
        expect(estimate[:taxes_rate]).to eq(10)
      end
    end
  end

  context "when creating credit note with possible rounding issues" do
    context "when creating credit notes for small items with taxes, so sum of items with their taxes is bigger than invoice total amount" do
      let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 20) }

      context "when two similar items are refunded separately" do
        let(:add_ons) { create_list(:add_on, 2, organization:, amount_cents: 68_33) }

        it "solves the rounding issue" do
          #  create a one off invoice with two addons and small amounts as feed
          create_one_off_invoice(customer, add_ons, taxes: [tax.code])
          # invoice amount should be with taxes calculated on items sum:
          invoice = customer.invoices.order(:created_at).last
          expect(invoice.total_amount_cents).to eq(163_99)
          expect(invoice.taxes_amount_cents).to eq(27_33)
          fees = invoice.fees

          Payments::ManualCreateService.call(
            organization:,
            params: {invoice_id: invoice.id, amount_cents: 500, reference: "ref3"}
          )

          # estimate and create credit notes for first item - full refund; the taxes are rounded to higher number
          estimate_credit_note(
            {invoice_id: invoice.id,
             items: [
               {
                 fee_id: fees[0].id,
                 amount_cents: 68_33
               }
             ]}
          )

          # Estimate the credit notes amount on one fee rounds the taxes to higher number
          estimate = json[:estimated_credit_note]
          expect(estimate).to include(
            taxes_amount_cents: 13_67,
            precise_taxes_amount_cents: "1366.6",
            sub_total_excluding_taxes_amount_cents: 68_33,
            max_creditable_amount_cents: 82_00,
            max_refundable_amount_cents: 5_00,
            taxes_rate: 20.0
          )

          Payments::ManualCreateService.call(
            organization:,
            params: {invoice_id: invoice.id, amount_cents: 7700, reference: "ref3"}
          )

          # Emit a credit note on only one fee
          create_credit_note({
            invoice_id: invoice.id,
            reason: :other,
            credit_amount_cents: 0,
            refund_amount_cents: 82_00,
            items: [
              {
                fee_id: fees[0].id,
                amount_cents: 68_33
              }
            ]
          })

          credit_note = invoice.credit_notes.order(:created_at).last
          expect(credit_note).to have_attributes(
            sub_total_excluding_taxes_amount_cents: 68_33,
            taxes_amount_cents: 13_67,
            refund_amount_cents: 82_00,
            total_amount_cents: 82_00,
            precise_taxes_amount_cents: 1366.6,
            precise_total: 8199.6,
            taxes_rounding_adjustment: 0.4
          )

          Payments::ManualCreateService.call(
            organization:,
            params: {invoice_id: invoice.id, amount_cents: 8_000, reference: "ref3"}
          )

          # when issuing second credit note, it should be rounded to lower number
          estimate_credit_note({
            invoice_id: invoice.id,
            items: [
              {
                fee_id: fees[1].id,
                amount_cents: 68_33
              }
            ]
          })

          estimate = json[:estimated_credit_note]

          expect(estimate).to include(
            taxes_amount_cents: 13_66,
            precise_taxes_amount_cents: "1366.2",
            sub_total_excluding_taxes_amount_cents: 68_33,
            max_creditable_amount_cents: 81_99,
            max_refundable_amount_cents: 80_00,
            taxes_rate: 20.0
          )

          Payments::ManualCreateService.call(
            organization:,
            params: {invoice_id: invoice.id, amount_cents: 1_99, reference: "ref3"}
          )

          # Emit a credit note on only one fee
          create_credit_note({
            invoice_id: invoice.id,
            reason: :other,
            credit_amount_cents: 0,
            refund_amount_cents: 81_99,
            items: [
              {
                fee_id: fees[1].id,
                amount_cents: 68_33
              }
            ]
          })

          credit_note = invoice.credit_notes.order(:created_at).last
          expect(credit_note).to have_attributes(
            sub_total_excluding_taxes_amount_cents: 68_33,
            refund_amount_cents: 81_99,
            total_amount_cents: 81_99,
            taxes_amount_cents: 13_66,
            precise_taxes_amount_cents: 1366.2,
            precise_total: 8199.2,
            taxes_rounding_adjustment: -0.2
          )
        end
      end

      context "when four items are refunded separately, some whole, some in parts" do
        let(:add_ons) { create_list(:add_on, 4, organization:, amount_cents: 68_33) }

        it "solves the rounding issue" do
          #  create a one off invoice with two addons and small amounts as feed
          create_one_off_invoice(customer, add_ons, taxes: [tax.code])
          # invoice amount should be with taxes calculated on items sum:
          invoice = customer.invoices.order(:created_at).last
          expect(invoice.total_amount_cents).to eq(327_98)
          expect(invoice.taxes_amount_cents).to eq(54_66)
          fees = invoice.fees
          invoice.update(payment_status: "succeeded")

          Payments::ManualCreateService.call(
            organization:,
            params: {invoice_id: invoice.id, amount_cents: 300_00, reference: "ref3"}
          )
          invoice.reload

          # estimate and create credit notes for first three items - full refund; the taxes are rounded to higher number
          3.times do |i|
            estimate_credit_note({
              invoice_id: invoice.id,
              items: [
                {
                  fee_id: fees[i].id,
                  amount_cents: 68_33
                }
              ]
            })

            # Estimate the credit notes amount on one fee rounds the taxes to higher number
            estimate = json[:estimated_credit_note]
            expect(estimate).to include(
              taxes_amount_cents: 13_67,
              precise_taxes_amount_cents: "1366.6",
              sub_total_excluding_taxes_amount_cents: 68_33,
              max_creditable_amount_cents: 82_00,
              max_refundable_amount_cents: 82_00,
              taxes_rate: 20.0
            )

            # Emit a credit note on only one fee
            create_credit_note({
              invoice_id: invoice.id,
              reason: :other,
              credit_amount_cents: 0,
              refund_amount_cents: 82_00,
              items: [
                {
                  fee_id: fees[i].id,
                  amount_cents: 68_33
                }
              ]
            })

            credit_note = invoice.credit_notes.order(:created_at).last
            expect(credit_note).to have_attributes(
              refund_amount_cents: 82_00,
              total_amount_cents: 82_00,
              taxes_amount_cents: 13_67,
              precise_taxes_amount_cents: 1366.6,
              precise_total: 8199.6,
              taxes_rounding_adjustment: 0.4
            )
          end
          # this value is wrong because of all rounding because if we subtract issued credit notes from the invoice, it
          # will result in 327_98 - 82_00 * 3 = 81_98
          expect(invoice.creditable_amount_cents).to eq(8200)

          # split last refundable item into three chunks, first's taxes are rounded to lower number
          # next two are rounded to higher number
          # cn_1 => 13.67, cn2 => 22.33, cn3 => 32.33
          # CN1
          estimate_credit_note({
            invoice_id: invoice.id,
            items: [
              {
                fee_id: fees[3].id,
                amount_cents: 13_67
              }
            ]
          })

          estimate = json[:estimated_credit_note]
          expect(estimate).to include(
            taxes_amount_cents: 273,
            precise_taxes_amount_cents: "273.4",
            sub_total_excluding_taxes_amount_cents: 1367,
            max_creditable_amount_cents: 1640,
            max_refundable_amount_cents: 1640,
            taxes_rate: 20.0
          )

          # Emit a credit note on only one fee
          create_credit_note({
            invoice_id: invoice.id,
            reason: :other,
            credit_amount_cents: 0,
            refund_amount_cents: 1640,
            items: [
              {
                fee_id: fees[3].id,
                amount_cents: 1367
              }
            ]
          })

          credit_note = invoice.credit_notes.order(:created_at).last
          expect(credit_note).to have_attributes(
            refund_amount_cents: 1640,
            total_amount_cents: 1640,
            taxes_amount_cents: 273,
            precise_taxes_amount_cents: 273.4
          )
          expect(credit_note.precise_total).to eq(1640.4)
          expect(credit_note.taxes_rounding_adjustment).to eq(-0.4)
          # real remaining: 81_98 - 16_40 = 65_58
          expect(invoice.creditable_amount_cents).to eq(6559)

          # cn_1 => 13.67, cn2 => 22.33, cn3 => 32.33
          # CN2
          estimate_credit_note({
            invoice_id: invoice.id,
            items: [
              {
                fee_id: fees[3].id,
                amount_cents: 22_33
              }
            ]
          })

          estimate = json[:estimated_credit_note]
          expect(estimate).to include(
            taxes_amount_cents: 447,
            precise_taxes_amount_cents: "446.6",
            sub_total_excluding_taxes_amount_cents: 2233,
            max_creditable_amount_cents: 2680,
            max_refundable_amount_cents: 2680,
            taxes_rate: 20.0
          )

          # Emit a credit note on only one fee
          create_credit_note({
            invoice_id: invoice.id,
            reason: :other,
            credit_amount_cents: 0,
            refund_amount_cents: 2680,
            items: [
              {
                fee_id: fees[3].id,
                amount_cents: 2233
              }
            ]
          })

          credit_note = invoice.credit_notes.order(:created_at).last
          expect(credit_note).to have_attributes(
            refund_amount_cents: 2680,
            total_amount_cents: 2680,
            taxes_amount_cents: 447,
            precise_taxes_amount_cents: 446.6,
            precise_total: 2679.6,
            taxes_rounding_adjustment: 0.4
          )
          # real remaining: 65_58 - 26_80 = 38_78
          expect(invoice.creditable_amount_cents).to eq(3880)

          # cn_1 => 13.67, cn2 => 22.33, cn3 => 32.33
          # CN3
          estimate_credit_note({
            invoice_id: invoice.id,
            items: [
              {
                fee_id: fees[3].id,
                amount_cents: 32_33
              }
            ]
          })

          estimate = json[:estimated_credit_note]
          expect(estimate).to include(
            taxes_amount_cents: 6_45,
            precise_taxes_amount_cents: "645.4",
            sub_total_excluding_taxes_amount_cents: 32_33,
            max_creditable_amount_cents: 38_78,
            max_refundable_amount_cents: 10_80, # invoice.total_paid_amount_cents - invoice.credit_notes.sum(:refund_amount_cents)
            taxes_rate: 20.0
          )

          Payments::ManualCreateService.call(
            organization:,
            params: {invoice_id: invoice.id, amount_cents: 27_98, reference: "ref3"}
          )

          # Emit a credit note on only one fee
          create_credit_note({
            invoice_id: invoice.id,
            reason: :other,
            credit_amount_cents: 0,
            refund_amount_cents: 3878,
            items: [
              {
                fee_id: fees[3].id,
                amount_cents: 3233
              }
            ]
          })

          credit_note = invoice.credit_notes.order(:created_at).last
          expect(credit_note).to have_attributes(
            sub_total_excluding_taxes_amount_cents: 32_33,
            refund_amount_cents: 38_78,
            total_amount_cents: 38_78,
            taxes_amount_cents: 645,
            precise_taxes_amount_cents: 645.4,
            precise_total: 38_78.4,
            taxes_rounding_adjustment: -0.4
          )

          expect(invoice.creditable_amount_cents).to eq(0)
        end
      end
    end

    context "when creating credit note with small items and applied coupons" do
      let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 20) }
      let(:plan_tax) { create(:tax, organization:, name: "Plan Tax", rate: 20, applied_to_organization: false) }
      let(:plan) do
        create(
          :plan,
          organization:,
          interval: :monthly,
          amount_cents: 1_999,
          pay_in_advance: false
        )
      end

      let(:charge1) do
        create(
          :standard_charge,
          plan:,
          min_amount_cents: 6833
        )
      end

      let(:charge2) do
        create(
          :standard_charge,
          plan:,
          min_amount_cents: 200_33
        )
      end

      let(:coupon) do
        create(
          :coupon,
          organization:,
          amount_cents: 10_00,
          expiration: :no_expiration,
          coupon_type: :fixed_amount,
          frequency: :forever,
          limited_plans: false,
          reusable: true
        )
      end

      before do
        charge1
        charge2
      end

      it "calculates all roundings" do
        # Creates two subscriptions
        travel_to(DateTime.new(2022, 12, 19, 12)) do
          create_subscription(
            {external_customer_id: customer.external_id,
             external_id: "#{customer.external_id}_1",
             plan_code: plan.code,
             billing_time: :anniversary}
          )
        end

        # Apply a coupon twice to the customer
        travel_to(DateTime.new(2023, 8, 29)) do
          apply_coupon(
            {external_customer_id: customer.external_id,
             coupon_code: coupon.code,
             amount_cents: 10_00}
          )
        end

        # Bill subscription on an anniversary date
        travel_to(DateTime.new(2023, 10, 19)) do
          perform_billing
        end

        invoice = customer.invoices.order(created_at: :desc).first
        # fees sum = 19_99 + 68_33 + 200_33 = 288_65
        # applied coupon - 10_00
        # subtotal before taxes - 278_65
        # taxes = 5573
        expect(invoice.total_amount_cents).to eq(334_38)

        # issue a CN for the full subscription fee - 19_99 before taxes and coupons
        subscription_fee = invoice.fees.find(&:subscription?)
        estimate_credit_note({
          invoice_id: invoice.id,
          items: [
            {
              fee_id: subscription_fee.id,
              amount_cents: 19_99
            }
          ]
        })

        estimate = json[:estimated_credit_note]
        expect(estimate).to include(
          taxes_amount_cents: 3_86,
          precise_taxes_amount_cents: "385.94932",
          sub_total_excluding_taxes_amount_cents: 19_30,
          max_creditable_amount_cents: 23_16,
          coupons_adjustment_amount_cents: 69,
          taxes_rate: 20.0
        )
        create_credit_note({
          invoice_id: invoice.id,
          reason: :other,
          credit_amount_cents: 23_16,
          items: [
            {
              fee_id: subscription_fee.id,
              amount_cents: 19_99
            }
          ]
        })

        credit_note = invoice.credit_notes.order(:created_at).last
        expect(credit_note).to have_attributes(
          credit_amount_cents: 23_16,
          total_amount_cents: 23_16,
          taxes_amount_cents: 3_86,
          precise_taxes_amount_cents: 385.94932,
          precise_coupons_adjustment_amount_cents: 69.25342,
          precise_total: 2315.6959,
          taxes_rounding_adjustment: 0.05068
        )

        # real remaining: 334_38 - 23_16 = 311_22
        expect(invoice.creditable_amount_cents).to eq(31122.253421098216)

        # issue a CN for the full first charge - 68_33 before taxes and coupons
        first_charge = invoice.fees.find { |fee| fee.amount_cents == 68_33 }
        estimate_credit_note({
          invoice_id: invoice.id,
          items: [
            {
              fee_id: first_charge.id,
              amount_cents: 68_33
            }
          ]
        })

        estimate = json[:estimated_credit_note]
        expect(estimate).to include(
          taxes_amount_cents: 13_19,
          precise_taxes_amount_cents: "1319.25547",
          sub_total_excluding_taxes_amount_cents: 65_96,
          max_creditable_amount_cents: 79_15,
          coupons_adjustment_amount_cents: 2_37,
          taxes_rate: 20.0
        )
        create_credit_note({
          invoice_id: invoice.id,
          reason: :other,
          credit_amount_cents: 79_15,
          items: [
            {
              fee_id: first_charge.id,
              amount_cents: 6833
            }
          ]
        })

        credit_note = invoice.credit_notes.order(:created_at).last
        expect(credit_note).to have_attributes(
          credit_amount_cents: 79_15,
          total_amount_cents: 79_15,
          taxes_amount_cents: 13_19,
          precise_taxes_amount_cents: 1319.25547,
          precise_coupons_adjustment_amount_cents: 236.72267
        )
        expect(credit_note.precise_total).to eq(7915.5328)
        expect(credit_note.taxes_rounding_adjustment).to eq(-0.25547)
        # real remaining: 311_22 - 79_16 = 232_07
        expect(invoice.creditable_amount_cents).to eq(23206.97609561753)

        # issue a CN for the full last charge - 200_33 before taxes and coupons
        last_charge = invoice.fees.find { |fee| fee.amount_cents == 200_33 }
        estimate_credit_note({
          invoice_id: invoice.id,
          items: [
            {
              fee_id: last_charge.id,
              amount_cents: 200_33
            }
          ]
        })

        estimate = json[:estimated_credit_note]
        expect(estimate).to include(
          taxes_amount_cents: 38_68,
          precise_taxes_amount_cents: "3868.00001",
          sub_total_excluding_taxes_amount_cents: 193_39,
          max_creditable_amount_cents: 232_07,
          coupons_adjustment_amount_cents: 6_94,
          taxes_rate: 20.0
        )

        create_credit_note({
          invoice_id: invoice.id,
          reason: :other,
          credit_amount_cents: 232_07,
          items: [
            {
              fee_id: last_charge.id,
              amount_cents: 200_33
            }
          ]
        })

        credit_note = invoice.credit_notes.order(:created_at).last
        expect(credit_note).to have_attributes(
          credit_amount_cents: 232_07,
          total_amount_cents: 232_07,
          taxes_amount_cents: 38_68,
          precise_taxes_amount_cents: 3868.00001,
          precise_coupons_adjustment_amount_cents: 694.0239,
          precise_total: 23206.97611,
          taxes_rounding_adjustment: -0.00001
        )

        # real remaining: 232_07 - 23_207 = 0
        expect(invoice.creditable_amount_cents).to eq(0)
      end
    end
  end

  context "when invoice is prepaid credit" do
    it "behaves differently depending on the invoice payment status, wallet balance and wallet status" do
      # Create a prepaid credit invoice for 15 credits
      create_wallet({
        external_customer_id: customer.external_id,
        rate_amount: "1",
        name: "Wallet1",
        currency: "EUR",
        invoice_requires_successful_payment: false # default
      })
      wallet = customer.wallets.sole

      create_wallet_transaction({
        wallet_id: wallet.id,
        paid_credits: "15"
      })
      wt = WalletTransaction.find json[:wallet_transactions].first[:lago_id]

      expect(wt.status).to eq "pending"
      expect(wt.transaction_status).to eq "purchased"

      # Customer does not have a payment_provider set yet
      invoice = customer.invoices.credit.sole
      expect(invoice.status).to eq "finalized"

      # it does not allow to create credit notes on invoices with payment status pending
      expect(invoice.creditable_amount_cents).to eq 0
      expect(invoice.refundable_amount_cents).to eq 0

      estimate_credit_note(
        {invoice_id: invoice.id,
         items: [
           {
             fee_id: invoice.fees.first.id,
             amount_cents: 15
           }
         ]},
        raise_on_error: false
      )
      expect(response).to have_http_status(:method_not_allowed)

      # it does not allow to create credit notes on invoices with payment status pending
      create_credit_note({
        invoice_id: invoice.id,
        reason: :other,
        credit_amount_cents: 0,
        refund_amount_cents: 15,
        items: [
          {
            fee_id: invoice.fees.first.id,
            amount_cents: 15
          }
        ]
      }, raise_on_error: false)
      expect(response).to have_http_status(:method_not_allowed)

      # pay the invoice
      update_invoice(invoice, {payment_status: :succeeded})
      perform_all_enqueued_jobs
      wallet.reload
      expect(wallet.balance_cents).to eq 1500

      Payments::ManualCreateService.call(
        organization:,
        params: {invoice_id: invoice.id, amount_cents: 1500, reference: "ref3"}
      )

      invoice.reload

      # it allows to estimate a credit notes on credit invoices with payment status succeeded
      estimate_credit_note({
        invoice_id: invoice.id,
        items: [
          {
            fee_id: invoice.fees.first.id,
            amount_cents: 10
          }
        ]
      })

      estimate = json[:estimated_credit_note]
      expect(estimate[:sub_total_excluding_taxes_amount_cents]).to eq(10)
      expect(estimate[:max_refundable_amount_cents]).to eq(10)
      expect(estimate[:max_creditable_amount_cents]).to eq(0)

      # it allows to create credit notes on credit invoices with payment status succeeded
      # and voids the corresponding amount of credits in the associated active wallet
      create_credit_note({
        invoice_id: invoice.id,
        reason: :other,
        credit_amount_cents: 0,
        refund_amount_cents: 500,
        items: [
          {
            fee_id: invoice.fees.first.id,
            amount_cents: 500
          }
        ]
      })
      perform_all_enqueued_jobs
      credit_note = invoice.credit_notes.order(:created_at).last
      expect(credit_note.refund_amount_cents).to eq(500)
      expect(credit_note.total_amount_cents).to eq(500)
      wallet_transaction = wallet.wallet_transactions.order(:created_at).last
      expect(wallet_transaction.status).to eq("settled")
      expect(wallet_transaction.transaction_status).to eq("voided")
      expect(wallet_transaction.credit_note_id).to eq(credit_note.id)
      expect(wallet.reload.balance_cents).to eq(1000)

      # Void most of the remaining balance to leave only 5 cents
      # Balance is 1000 cents (= 10 credits), void 9.95 credits to leave 5 cents
      create_wallet_transaction({
        wallet_id: wallet.id,
        voided_credits: "9.95"
      })
      perform_all_enqueued_jobs
      expect(wallet.reload.balance_cents).to eq(5)

      # when estimating a credit note with amount higher than the remaining balance, it throws an error
      estimate_credit_note({
        invoice_id: invoice.id,
        items: [
          {
            fee_id: invoice.fees.first.id,
            amount_cents: 10
          }
        ]
      }, raise_on_error: false)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("higher_than_wallet_balance")

      # when creating a credit note with amount higher than remaining balance, it throws an error
      create_credit_note({
        invoice_id: invoice.id,
        reason: :other,
        refund_amount_cents: 10,
        items: [
          {
            fee_id: invoice.fees.first.id,
            amount_cents: 10
          }
        ]
      }, raise_on_error: false)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("higher_than_wallet_balance")

      expect(wallet.reload.balance_cents).to eq(5)

      # when wallet is terminated, it does not allow to create credit notes
      wallet.update(status: :terminated)

      estimate_credit_note({
        invoice_id: invoice.id,
        items: [
          {
            fee_id: invoice.fees.first.id,
            amount_cents: 1
          }
        ]
      }, raise_on_error: false)
      expect(response).to have_http_status(:method_not_allowed)
      expect(response.body).to include("invalid_type_or_status")

      create_credit_note({
        invoice_id: invoice.id,
        reason: :other,
        refund_amount_cents: 1,
        items: [
          {
            fee_id: invoice.fees.first.id,
            amount_cents: 1
          }
        ]
      }, raise_on_error: false)
      expect(response).to have_http_status(:method_not_allowed)
      expect(response.body).to include("invalid_type_or_status")
    end
  end
end
