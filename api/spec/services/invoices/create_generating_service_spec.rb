# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::CreateGeneratingService do
  subject(:create_service) do
    described_class.new(customer:, invoice_type:, currency:, datetime:, charge_in_advance:, invoicing_reason:)
  end

  let(:customer) { create(:customer) }
  let(:invoice_type) { :one_off }
  let(:currency) { "EUR" }
  let(:datetime) { Time.current }
  let(:charge_in_advance) { false }
  let(:invoicing_reason) { "subscription_starting" }
  let(:recurring) { false }

  describe "call" do
    it "creates an invoice" do
      result = create_service.call

      expect(result).to be_success
      expect(result.invoice).to be_persisted
      expect(result.invoice).to be_generating
      expect(result.invoice.organization).to eq(customer.organization)
      expect(result.invoice.customer).to eq(customer)
      expect(result.invoice.billing_entity).to eq(customer.billing_entity)
      expect(result.invoice).to be_one_off
      expect(result.invoice.currency).to eq(currency)
      expect(result.invoice.timezone).to eq(customer.applicable_timezone)
      expect(result.invoice.issuing_date).to eq(datetime.to_date)
      expect(result.invoice.payment_due_date).to eq(datetime.to_date)
      expect(result.invoice.net_payment_term).to eq(customer.applicable_net_payment_term)
    end

    context "with customer timezone" do
      let(:customer) { create(:customer, timezone: "America/Los_Angeles") }
      let(:datetime) { Time.zone.parse("2022-11-25 01:00:00") }

      it "assigns the issuing date in the customer timezone" do
        result = create_service.call

        expect(result.invoice.timezone).to eq("America/Los_Angeles")
        expect(result.invoice.issuing_date.to_s).to eq("2022-11-24")
        expect(result.invoice.expected_finalization_date.to_s).to eq("2022-11-24")
      end
    end

    context "when an explicit billing_entity is passed" do
      subject(:create_service) do
        described_class.new(customer:, invoice_type:, currency:, datetime:, billing_entity:)
      end

      let(:billing_entity) { create(:billing_entity, organization: customer.organization) }

      it "stamps the invoice with the provided billing entity" do
        result = create_service.call

        expect(result).to be_success
        expect(result.invoice.billing_entity).to eq(billing_entity)
      end
    end

    context "with applicable net payment term" do
      let(:customer) { create(:customer, net_payment_term: 3) }

      it "assigns the payment due date based on the net payment term" do
        result = create_service.call

        expect(result.invoice.net_payment_term).to eq(3)
        expect(result.invoice.payment_due_date.to_s).to eq((datetime + 3.days).to_date.to_s)
      end
    end

    context "when a block is passed to the method" do
      let(:invoice_type) { :subscription }
      let(:subscription) { create(:subscription, customer:, started_at: Time.current - 1.day) }

      it "creates an invoice" do
        result = create_service.call do |invoice|
          invoice.invoice_subscriptions.create!(
            organization: customer.organization,
            subscription:,
            recurring:,
            from_datetime: datetime.beginning_of_month,
            to_datetime: datetime.end_of_month,
            charges_from_datetime: datetime.end_of_month,
            charges_to_datetime: datetime.end_of_month
          )
        end

        expect(result).to be_success
        expect(result.invoice).to be_persisted
        expect(result.invoice).to be_generating
        expect(result.invoice.organization).to eq(customer.organization)
        expect(result.invoice.customer).to eq(customer)
        expect(result.invoice).to be_subscription
        expect(result.invoice.currency).to eq(currency)
        expect(result.invoice.timezone).to eq(customer.applicable_timezone)
        expect(result.invoice.issuing_date).to eq(datetime.to_date)
        expect(result.invoice.expected_finalization_date).to eq(datetime.to_date)
        expect(result.invoice.payment_due_date).to eq(datetime.to_date)
        expect(result.invoice.net_payment_term).to eq(customer.applicable_net_payment_term)

        expect(result.invoice.invoice_subscriptions.count).to eq(1)
      end
    end

    context "when invoice type is subscription" do
      let(:invoice_type) { :subscription }
      let(:customer) { create(:customer, invoice_grace_period: 3) }

      it "creates an invoice with grace period" do
        result = create_service.call

        expect(result.invoice.issuing_date.to_s).to eq((datetime + 3.days).to_date.to_s)
      end

      context "when charge pay in advance invoice is generated" do
        let(:charge_in_advance) { true }

        it "creates an invoice with correct issuing date" do
          result = create_service.call

          expect(result.invoice.issuing_date.to_s).to eq(datetime.to_date.to_s)
          expect(result.invoice.expected_finalization_date.to_s).to eq(datetime.to_date.to_s)
        end
      end

      context "with customer timezone" do
        let(:customer) { create(:customer, timezone: "America/Los_Angeles", invoice_grace_period: 3) }
        let(:datetime) { Time.zone.parse("2022-11-25 01:00:00") }

        it "assigns the issuing date in the customer timezone" do
          result = create_service.call

          expect(result.invoice.timezone).to eq("America/Los_Angeles")
          expect(result.invoice.issuing_date.to_s).to eq("2022-11-27")
          expect(result.invoice.expected_finalization_date.to_s).to eq("2022-11-27")
        end
      end

      context "when subscription_gated is true" do
        subject(:create_service) do
          described_class.new(customer:, invoice_type:, currency:, datetime:, charge_in_advance:, invoicing_reason:, subscription_gated: true)
        end

        it "skips grace period and uses current date as issuing date" do
          result = create_service.call

          expect(result.invoice.issuing_date.to_s).to eq(datetime.to_date.to_s)
          expect(result.invoice.expected_finalization_date.to_s).to eq(datetime.to_date.to_s)
        end
      end
    end

    context "when customer is a partner account", :premium do
      let(:customer) { create(:customer, account_type: "partner") }

      it "returns a failure" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
      end

      context "when revenue share premium feature is enabled" do
        let(:customer) { create(:customer, organization:, account_type: "partner") }

        let(:organization) do
          create(:organization, premium_integrations: ["revenue_share"])
        end

        it "creates an invoice with self billed" do
          result = create_service.call

          expect(result.invoice.self_billed).to eq(true)
        end
      end
    end

    context "with issuing date preferences" do
      let(:customer) do
        create(
          :customer,
          subscription_invoice_issuing_date_anchor:,
          subscription_invoice_issuing_date_adjustment:,
          invoice_grace_period:
        )
      end

      let(:invoice_type) { :subscription }
      let(:invoicing_reason) { "subscription_periodic" }
      let(:invoice_grace_period) { 3 }

      context "with current_period_end + keep_anchor" do
        let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
        let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }

        it "sets issuing_date to the current billing period end date" do
          result = create_service.call

          expect(result.invoice.issuing_date).to eq(datetime.to_date - 1.day)
          expect(result.invoice.expected_finalization_date).to eq(datetime.to_date + 3.days)
        end

        context "with no invoice_grace_period" do
          let(:invoice_grace_period) { 0 }

          it "sets issuing_date to the current billing period end date" do
            result = create_service.call

            expect(result.invoice.issuing_date).to eq(datetime.to_date - 1.day)
            expect(result.invoice.expected_finalization_date).to eq(datetime.to_date)
          end
        end
      end

      context "with current_period_end + align_with_finalization_date" do
        let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
        let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }

        it "sets issuing_date to the current billing period end date + grace period" do
          result = create_service.call

          expect(result.invoice.issuing_date).to eq(datetime.to_date + 3.days)
          expect(result.invoice.expected_finalization_date).to eq(datetime.to_date + 3.days)
        end

        context "with no invoice_grace_period" do
          let(:invoice_grace_period) { 0 }

          it "sets issuing_date to the current billing period end date" do
            result = create_service.call

            expect(result.invoice.issuing_date).to eq(datetime.to_date - 1.day)
            expect(result.invoice.expected_finalization_date).to eq(datetime.to_date)
          end
        end
      end

      context "with next_period_start + keep_anchor" do
        let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
        let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }

        it "sets issuing_date to the next billing period start date" do
          result = create_service.call

          expect(result.invoice.issuing_date).to eq(datetime.to_date)
          expect(result.invoice.expected_finalization_date).to eq(datetime.to_date + 3.days)
        end

        context "with no invoice_grace_period" do
          let(:invoice_grace_period) { 0 }

          it "sets issuing_date to the next billing period start date" do
            result = create_service.call

            expect(result.invoice.issuing_date).to eq(datetime.to_date)
            expect(result.invoice.expected_finalization_date).to eq(datetime.to_date)
          end
        end
      end

      context "with next_period_start + align_with_finalization_date" do
        let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
        let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }

        it "sets issuing_date to the next billing period start date + grace period" do
          result = create_service.call

          expect(result.invoice.issuing_date).to eq(datetime.to_date + 3.days)
          expect(result.invoice.expected_finalization_date).to eq(datetime.to_date + 3.days)
        end

        context "with no invoice_grace_period" do
          let(:invoice_grace_period) { 0 }

          it "sets issuing_date to the next billing period start date" do
            result = create_service.call

            expect(result.invoice.issuing_date).to eq(datetime.to_date)
            expect(result.invoice.expected_finalization_date).to eq(datetime.to_date)
          end
        end
      end

      context "with no preferences set on the customer level" do
        let(:billing_entity) do
          create(
            :billing_entity,
            subscription_invoice_issuing_date_anchor: "current_period_end",
            subscription_invoice_issuing_date_adjustment: "keep_anchor",
            invoice_grace_period: 3
          )
        end

        let(:customer) { create(:customer, billing_entity:) }

        it "uses billing_entity preferences" do
          result = create_service.call

          expect(result.invoice.issuing_date).to eq(datetime.to_date - 1.day)
          expect(result.invoice.expected_finalization_date).to eq(datetime.to_date + 3.days)
        end
      end

      context "when invoice is not recurring" do
        let(:invoicing_reason) { "subscription_starting" }

        let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
        let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }

        it "ignores all issuing date preferences" do
          result = create_service.call

          expect(result.invoice.issuing_date).to eq(datetime.to_date + 3.days)
          expect(result.invoice.expected_finalization_date).to eq(datetime.to_date + 3.days)
        end
      end

      context "with a non-subscription invoice" do
        let(:invoice_type) { :one_off }

        let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
        let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }
        let(:invoice_grace_period) { 3 }

        it "does not include invoice_grace_period" do
          result = create_service.call

          expect(result.invoice.issuing_date).to eq(datetime.to_date)
          expect(result.invoice.expected_finalization_date).to eq(datetime.to_date)
        end
      end
    end
  end
end
