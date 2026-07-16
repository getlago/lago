# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::CreateInvoiceSubscriptionService do
  subject(:create_service) { described_class.new(invoice:, subscriptions:, timestamp:, invoicing_reason:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }

  let(:invoice) { create(:invoice, organization:, customer:, status: :generating) }
  let(:subscriptions) { [subscription] }
  let(:timestamp) { Time.zone.parse("2022-03-07T00:00:00") }
  let(:invoicing_reason) { :subscription_periodic }

  let(:subscription) do
    create(
      :subscription,
      plan:,
      customer:,
      billing_time:,
      subscription_at:,
      started_at:,
      created_at:,
      status:,
      terminated_at:
    )
  end

  let(:started_at) { Time.zone.parse("2021-06-06T00:00:00") }
  let(:created_at) { started_at }
  let(:subscription_at) { started_at }
  let(:terminated_at) { nil }
  let(:status) { :active }
  let(:plan) { create(:plan, organization:, interval:, pay_in_advance:) }
  let(:pay_in_advance) { false }
  let(:billing_time) { :anniversary }
  let(:interval) { "monthly" }

  describe "#call" do
    it "creates invoice subscriptions" do
      result = create_service.call

      expect(result).to be_success
      expect(result.invoice_subscriptions.count).to eq(1)

      invoice_subscription = result.invoice_subscriptions.first
      expect(invoice_subscription).to have_attributes(
        invoice:,
        subscription:,
        timestamp: match_datetime(timestamp),
        from_datetime: match_datetime(Time.zone.parse("2022-02-06 00:00:00")),
        to_datetime: match_datetime(Time.zone.parse("2022-03-05 23:59:59")),
        charges_from_datetime: match_datetime(Time.zone.parse("2022-02-06 00:00:00")),
        charges_to_datetime: match_datetime(Time.zone.parse("2022-03-05 23:59:59")),
        fixed_charges_from_datetime: match_datetime(Time.zone.parse("2022-02-06 00:00:00")),
        fixed_charges_to_datetime: match_datetime(Time.zone.parse("2022-03-05 23:59:59")),
        recurring: true,
        invoicing_reason: invoicing_reason.to_s
      )
    end

    context "when the plan is pay in advance" do
      let(:billing_time) { :calendar }
      let(:timestamp) { Time.zone.parse("2023-10-01T00:15:00") }
      let(:started_at) { Time.zone.parse("2023-08-01T08:00:01") }
      let(:pay_in_advance) { false }
      let(:status) { :terminated }
      let(:terminated_at) { Time.zone.parse("2023-10-01T00:00:00") }
      let(:invoicing_reason) { :subscription_terminating }

      it "creates invoice subscriptions with termination boundaries" do
        result = create_service.call

        expect(result).to be_success
        expect(result.invoice_subscriptions.count).to eq(1)

        invoice_subscription = result.invoice_subscriptions.first
        expect(invoice_subscription).to have_attributes(
          invoice:,
          subscription:,
          timestamp: match_datetime(timestamp),
          from_datetime: match_datetime(Time.zone.parse("2023-09-01T00:00:00")),
          to_datetime: match_datetime(Time.zone.parse("2023-09-30T23:59:59")),
          charges_from_datetime: match_datetime(Time.zone.parse("2023-09-01T00:00:00")),
          charges_to_datetime: match_datetime(Time.zone.parse("2023-09-30T23:59:59")),
          fixed_charges_from_datetime: match_datetime(Time.zone.parse("2023-09-01T00:00:00")),
          fixed_charges_to_datetime: match_datetime(Time.zone.parse("2023-09-30T23:59:59")),
          recurring: false,
          invoicing_reason: invoicing_reason.to_s
        )
      end

      context "when an existing invoice with the same boundaries" do
        let(:invoice_subscription) do
          create(
            :invoice_subscription,
            invoice: old_invoice,
            subscription:,
            from_datetime: Time.zone.parse("2023-09-01T00:00:00.000Z"),
            to_datetime: Time.zone.parse("2023-09-30T23:59:59.999Z").end_of_day,
            charges_from_datetime: Time.zone.parse("2023-09-01T00:00:00.000Z"),
            charges_to_datetime: Time.zone.parse("2023-09-30T23:59:59.999Z").end_of_day,
            fixed_charges_from_datetime: Time.zone.parse("2023-09-01T00:00:00.000Z"),
            fixed_charges_to_datetime: Time.zone.parse("2023-09-30T23:59:59.999Z").end_of_day,
            recurring: true,
            invoicing_reason: "subscription_periodic"
          )
        end

        let(:old_invoice) do
          create(
            :invoice,
            created_at: started_at - 3.months,
            customer: subscription.customer,
            organization: plan.organization
          )
        end

        before { invoice_subscription }

        it "creates an invoice subscriptions" do
          result = create_service.call

          expect(result).to be_success
          expect(result.invoice_subscriptions.count).to eq(1)

          invoice_subscription = result.invoice_subscriptions.first
          expect(invoice_subscription).to have_attributes(
            invoice:,
            subscription:,
            from_datetime: match_datetime(Time.zone.parse("2023-10-01T00:00:00")),
            to_datetime: match_datetime(Time.zone.parse("2023-10-01T00:00:00")),
            charges_from_datetime: match_datetime(Time.zone.parse("2023-10-01T00:00:00")),
            charges_to_datetime: match_datetime(Time.zone.parse("2023-10-01T00:00:00")),
            fixed_charges_from_datetime: match_datetime(Time.zone.parse("2023-10-01T00:00:00")),
            fixed_charges_to_datetime: match_datetime(Time.zone.parse("2023-10-01T00:00:00")),
            recurring: false,
            invoicing_reason: invoicing_reason.to_s
          )
        end
      end
    end

    context "when two subscriptions are given" do
      let(:subscription2) do
        create(
          :subscription,
          plan:,
          customer: subscription.customer,
          subscription_at: (Time.zone.now - 2.years).to_date,
          started_at: Time.zone.now - 2.years
        )
      end

      let(:subscriptions) { [subscription, subscription2] }

      it "creates subscription and charges fees for both" do
        result = create_service.call

        expect(result).to be_success
        expect(result.invoice_subscriptions.count).to eq(2)
      end

      context "when subscriptions are duplicated" do
        let(:subscriptions) { [subscription, subscription] }

        it "ensures charges are not duplicated" do
          result = create_service.call

          expect(result).to be_success
          expect(result.invoice_subscriptions.count).to eq(1)
        end
      end
    end

    context "when recurring and subscription is not active" do
      let(:invoicing_reason) { :subscription_periodic }
      let(:status) { :terminated }

      it "does not create an invoice subscription" do
        result = create_service.call

        expect(result).to be_success
        expect(result.invoice_subscriptions).to be_empty
      end
    end

    context "when invoice_subscription already exists" do
      let(:invoicing_reason) { :subscription_periodic }

      let(:date_service) do
        Subscriptions::DatesService.new_instance(
          subscription,
          Time.zone.at(timestamp),
          current_usage: false
        )
      end

      before do
        create(
          :invoice_subscription,
          subscription:,
          recurring: true,
          invoicing_reason: invoicing_reason.to_s,
          timestamp: timestamp,
          from_datetime: date_service.from_datetime,
          to_datetime: date_service.to_datetime,
          charges_from_datetime: date_service.charges_from_datetime,
          charges_to_datetime: date_service.charges_to_datetime,
          fixed_charges_from_datetime: date_service.fixed_charges_from_datetime,
          fixed_charges_to_datetime: date_service.fixed_charges_to_datetime
        )
      end

      it "returns a service failure" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("duplicated_invoices")
        expect(result.error.error_message).to be_present
      end

      context "when plan interval is yearly and charges are not paid on monthly basis" do
        let(:plan) do
          create(:plan, organization:, interval: "yearly", pay_in_advance: false, bill_charges_monthly: false)
        end

        it "returns a service failure" do
          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ServiceFailure)
          expect(result.error.code).to eq("duplicated_invoices")
          expect(result.error.error_message).to be_present
        end
      end

      context "when plan interval is yearly and charges are paid on monthly basis" do
        let(:plan) do
          create(:plan, organization:, interval: "yearly", pay_in_advance: false, bill_charges_monthly: true)
        end

        it "returns a service failure" do
          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ServiceFailure)
          expect(result.error.code).to eq("duplicated_invoices")
          expect(result.error.error_message).to be_present
        end
      end
    end

    context "when invoicing reason is upgrading" do
      let(:invoicing_reason) { :upgrading }
      let(:status) { :terminated }
      let(:timestamp) { Time.zone.parse("2023-10-01T00:00:00") }
      let(:terminated_at) { timestamp }

      it "creates an invoice subscription" do
        result = create_service.call

        expect(result).to be_success
        expect(result.invoice_subscriptions.count).to eq(1)

        invoice_subscription = result.invoice_subscriptions.first
        expect(invoice_subscription).to have_attributes(
          invoice:,
          subscription:,
          timestamp: match_datetime(timestamp),
          from_datetime: match_datetime(Time.zone.parse("2023-09-06T00:00:00")),
          to_datetime: match_datetime(timestamp),
          charges_from_datetime: match_datetime(Time.zone.parse("2023-09-06T00:00:00")),
          charges_to_datetime: match_datetime(timestamp),
          fixed_charges_from_datetime: match_datetime(Time.zone.parse("2023-09-06T00:00:00")),
          fixed_charges_to_datetime: match_datetime(timestamp),
          recurring: false,
          invoicing_reason: "subscription_terminating"
        )
      end
    end

    context "when invoicing reason is progressive_billing" do
      let(:invoicing_reason) { :progressive_billing }
      let(:timestamp) { Time.zone.parse("2023-10-01T00:00:00") }

      it "creates an invoice subscription" do
        result = create_service.call

        expect(result).to be_success
        expect(result.invoice_subscriptions.count).to eq(1)

        invoice_subscription = result.invoice_subscriptions.first
        expect(invoice_subscription).to have_attributes(
          invoice:,
          subscription:,
          timestamp: match_datetime(timestamp),
          charges_from_datetime: match_datetime(Time.zone.parse("2023-09-06T00:00:00")),
          charges_to_datetime: match_datetime("2023-10-05T23:59:59"),
          fixed_charges_from_datetime: match_datetime(Time.zone.parse("2023-09-06T00:00:00")),
          fixed_charges_to_datetime: match_datetime("2023-10-05T23:59:59"),
          recurring: false,
          invoicing_reason: "progressive_billing"
        )
      end
    end
  end
end
