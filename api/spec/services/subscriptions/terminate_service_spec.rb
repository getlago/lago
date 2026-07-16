# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::TerminateService do
  subject(:terminate_service) { described_class.new(subscription:) }

  let(:on_termination_credit_note) { nil }

  describe ".call" do
    subject(:result) { described_class.call(subscription:, on_termination_credit_note:) }

    let(:subscription) { create(:subscription) }

    it "terminates a subscription" do
      subject

      expect(result).to be_a(BaseResult)
      expect(result).to be_success
      expect(result.subscription).to be_present
      expect(result.subscription).to be_terminated
      expect(result.subscription.terminated_at).to be_present
    end

    context "when the subscription should sync with Hubspot" do
      let(:customer) { create(:customer, :with_hubspot_integration) }
      let(:subscription) { create(:subscription, customer:) }

      it "calls the hubspot update job after commit" do
        expect { subject }.to have_enqueued_job_after_commit(Integrations::Aggregator::Subscriptions::Hubspot::UpdateJob).with(subscription:).twice
      end
    end

    it "enqueues a BillSubscriptionJob after commit" do
      freeze_time do
        expect { subject }.to have_enqueued_job_after_commit(BillSubscriptionJob).with([subscription], Time.current, invoicing_reason: :subscription_terminating)
      end
    end

    it "does not create a credit note for the remaining days" do
      expect { subject }.not_to change(CreditNote, :count)
    end

    it "enqueues a BillNonInvoiceableFeesJob after commit" do
      freeze_time do
        expect { subject }.to have_enqueued_job_after_commit(BillNonInvoiceableFeesJob)
          .with([subscription], Time.current)
      end
    end

    it "enqueues a SendWebhookJob after commit" do
      expect { subject }.to have_enqueued_job_after_commit(SendWebhookJob).with("subscription.terminated", subscription)
    end

    context "when subscription is starting in the future" do
      let(:subscription) { create(:subscription, :pending) }

      it "cancels a subscription" do
        result = subject

        expect(result.subscription).to be_present
        expect(result.subscription).to be_canceled
        expect(result.subscription.canceled_at).to be_present
        expect(result.subscription.terminated_at).to be_nil
      end

      it "does not enqueue a BillSubscriptionJob" do
        expect { subject }.not_to have_enqueued_job(BillSubscriptionJob)
      end

      it "does not send subscription updated webhook" do
        subject
        expect(SendWebhookJob).not_to have_been_enqueued.with("subscription.updated", Subscription)
      end
    end

    context "when downgrade subscription is pending" do
      let(:subscription) { create(:subscription, :pending, previous_subscription:) }
      let(:previous_subscription) { create(:subscription) }

      it "does cancel it" do
        subject

        expect(result.subscription).to be_present
        expect(result.subscription).to be_canceled
        expect(result.subscription.canceled_at).to be_present
      end

      it "sends both subscription.terminated for the canceled and subscription.updated for the previous subscription" do
        subject

        expect(SendWebhookJob).to have_been_enqueued.with("subscription.terminated", subscription)
        expect(SendWebhookJob).to have_been_enqueued.with("subscription.updated", previous_subscription)
      end
    end

    context "when subscription is incomplete" do
      let(:subscription) { create(:subscription, :incomplete) }

      it "returns a validation error" do
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq({base: ["subscription_incomplete"]})
      end
    end

    context "when subscription is not found" do
      let(:subscription) { nil }

      it "returns an error" do
        subject

        expect(result.error.error_code).to eq("subscription_not_found")
      end
    end

    context "when pending next subscription" do
      let(:subscription) { create(:subscription) }
      let(:next_subscription) do
        create(
          :subscription,
          previous_subscription: subscription,
          status: :pending
        )
      end

      before { next_subscription }

      it "cancels the next subscription" do
        subject

        expect(result).to be_success
        expect(next_subscription.reload).to be_canceled
      end

      context "when called with upgrade: true" do
        subject(:result) { described_class.call(subscription:, on_termination_credit_note:, upgrade: true) }

        it "does not cancel the next subscription" do
          subject

          expect(result).to be_success
          expect(next_subscription.reload).to be_pending
        end
      end
    end

    context "when incomplete next subscription" do
      let(:subscription) { create(:subscription) }
      let(:next_subscription) do
        create(
          :subscription,
          previous_subscription: subscription,
          status: :incomplete
        )
      end

      before { next_subscription }

      it "returns a validation error" do
        subject

        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq({base: ["next_subscription_incomplete"]})
      end

      context "when called with upgrade: true" do
        subject(:result) { described_class.call(subscription:, on_termination_credit_note:, upgrade: true) }

        it "terminates the subscription and leaves the next subscription untouched" do
          subject

          expect(result).to be_success
          expect(subscription.reload).to be_terminated
          expect(next_subscription.reload).to be_incomplete
        end
      end
    end

    context "when subscription was paid in advance" do
      let(:plan) { create(:plan, :pay_in_advance) }
      let(:subscription) do
        create(
          :subscription,
          :anniversary,
          plan:,
          started_at: creation_time,
          subscription_at: creation_time,
          **(subscription_termination_credit_note ? {on_termination_credit_note: subscription_termination_credit_note} : {})
        )
      end
      let(:creation_time) { Time.current.beginning_of_month - 1.month }
      let(:date_service) do
        Subscriptions::DatesService.new_instance(
          subscription,
          Time.current.beginning_of_month,
          current_usage: false
        )
      end
      let(:invoice_subscription) do
        create(
          :invoice_subscription,
          invoice:,
          subscription:,
          recurring: true,
          from_datetime: date_service.from_datetime,
          to_datetime: date_service.to_datetime,
          charges_from_datetime: date_service.charges_from_datetime,
          charges_to_datetime: date_service.charges_to_datetime
        )
      end
      let(:invoice) do
        create(
          :invoice,
          customer: subscription.customer,
          currency: "EUR",
          sub_total_excluding_taxes_amount_cents: 100,
          fees_amount_cents: 100,
          taxes_amount_cents: 20,
          total_amount_cents: 120
        )
      end

      let(:last_subscription_fee) do
        create(
          :fee,
          subscription:,
          invoice:,
          amount_cents: 100,
          taxes_amount_cents: 20,
          invoiceable_type: "Subscription",
          invoiceable_id: subscription.id,
          taxes_rate: 20
        )
      end
      let(:subscription_termination_credit_note) { nil }

      before do
        invoice_subscription
        last_subscription_fee
      end

      [nil, "", "credit"].each do |on_termination_credit_note|
        context "when on_termination_credit_note is #{on_termination_credit_note.inspect}" do
          let(:on_termination_credit_note) { on_termination_credit_note }

          it "creates a credit note for the remaining days" do
            travel_to(Time.current.end_of_month - 4.days) do
              expect { subject }.to change(CreditNote, :count).by(1)
            end
          end

          it "updates the subscription termination behavior" do
            travel_to(Time.current.end_of_month - 4.days) do
              subject
              expect(subscription.reload.on_termination_credit_note).to eq("credit")
            end
          end
        end
      end

      context "when on_termination_credit_note is skip" do
        let(:on_termination_credit_note) { "skip" }

        it "does not create a credit note for the remaining days" do
          travel_to(Time.current.end_of_month - 4.days) do
            expect { subject }.not_to change(CreditNote, :count)
          end
        end

        it "updates the subscription termination behavior" do
          travel_to(Time.current.end_of_month - 4.days) do
            subject
            expect(subscription.reload.on_termination_credit_note).to eq("skip")
          end
        end
      end

      context "when on_termination_credit_note is refund" do
        let(:on_termination_credit_note) { "refund" }

        it "creates a credit note for the remaining days with refund" do
          travel_to(Time.current.end_of_month - 4.days) do
            expect { subject }.to change(CreditNote, :count).by(1)
          end
        end

        it "updates the subscription termination behavior" do
          travel_to(Time.current.end_of_month - 4.days) do
            subject
            expect(subscription.reload.on_termination_credit_note).to eq("refund")
          end
        end
      end

      context "when on_termination_credit_note is offset" do
        let(:on_termination_credit_note) { "offset" }

        it "creates a credit note for the remaining days with offset" do
          travel_to(Time.current.end_of_month - 4.days) do
            expect { subject }.to change(CreditNote, :count).by(1)
          end
        end

        it "updates the subscription termination behavior" do
          travel_to(Time.current.end_of_month - 4.days) do
            subject
            expect(subscription.reload.on_termination_credit_note).to eq("offset")
          end
        end
      end

      context "when on_termination_credit_note is not set" do
        subject(:result) { described_class.call(subscription:) }

        let(:subscription_termination_credit_note) { "skip" }

        it "rely on the subscription on_termination_credit_notek" do
          travel_to(Time.current.end_of_month - 4.days) do
            expect { subject }.not_to change(CreditNote, :count)
          end
        end
      end

      context "when on_termination_credit_note is invalid" do
        let(:on_termination_credit_note) { "invalid" }

        it "raises an error" do
          subject

          expect(result).to be_failure
          expect(result.error.messages).to include({on_termination_credit_note: ["invalid_value"]})
        end
      end

      context "when invoice subscription is not generated" do
        let(:invoice_subscription) { nil }

        it "does not create a credit note for the remaining days" do
          expect { subject }.not_to change(CreditNote, :count)
        end
      end

      context "when last subscription fee invoice has pending taxes" do
        let(:on_termination_credit_note) { "credit" }

        before { invoice.update!(status: :pending, tax_status: :pending) }

        it "returns a cannot_terminate_with_pending_taxes failure" do
          expect(result).to be_failure
          expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
          expect(result.error.code).to eq("cannot_terminate_with_pending_taxes")
        end

        it "does not mark the subscription as terminated" do
          subject
          expect(subscription.reload).not_to be_terminated
        end

        it "does not create a credit note" do
          expect { subject }.not_to change(CreditNote, :count)
        end
      end
    end

    context "when subscription is pay in arrears" do
      let(:on_termination_credit_note) { "credit" }

      before do
        subscription.plan.update!(pay_in_advance: false)
      end

      it "does not create a credit note" do
        expect { subject }.not_to change(CreditNote, :count)
      end

      it "updates the subscription termination behavior" do
        subject
        expect(subscription.reload.on_termination_credit_note).to eq(nil)
      end
    end

    context "with on_termination_invoice parameter" do
      subject(:result) { described_class.call(subscription:, on_termination_invoice:) }

      context "when on_termination_invoice is generate" do
        let(:on_termination_invoice) { "generate" }

        it "enqueues a BillSubscriptionJob" do
          freeze_time do
            expect { subject }.to have_enqueued_job_after_commit(BillSubscriptionJob).with([subscription], Time.current, invoicing_reason: :subscription_terminating)
          end
        end

        it "updates the subscription on_termination_invoice" do
          subject
          expect(subscription.reload.on_termination_invoice).to eq("generate")
        end
      end

      context "when on_termination_invoice is skip" do
        let(:on_termination_invoice) { "skip" }

        it "does not enqueue a BillSubscriptionJob" do
          expect { subject }.not_to have_enqueued_job(BillSubscriptionJob)
        end

        it "still enqueues a BillNonInvoiceableFeesJob" do
          freeze_time do
            expect { subject }.to have_enqueued_job_after_commit(BillNonInvoiceableFeesJob)
              .with([subscription], Time.current)
          end
        end

        it "updates the subscription on_termination_invoice" do
          subject
          expect(subscription.reload.on_termination_invoice).to eq("skip")
        end
      end

      context "when on_termination_invoice is invalid" do
        let(:on_termination_invoice) { "invalid" }

        it "raises an error" do
          subject

          expect(result).to be_failure
          expect(result.error.messages).to include({on_termination_invoice: ["invalid_value"]})
        end
      end
    end
  end

  describe "#terminate_and_start_next" do
    let(:subscription) { create(:subscription) }
    let(:next_subscription) { create(:subscription, :pending, previous_subscription_id: subscription.id) }
    let(:timestamp) { Time.zone.now.to_i }
    let(:activation_result) { Subscriptions::ActivateService::Result.new.tap { |r| r.subscription = next_subscription } }

    before do
      next_subscription
      allow(Subscriptions::ActivateService).to receive(:call!).and_return(activation_result)
    end

    it "delegates to ActivateService with the next subscription" do
      terminate_service.terminate_and_start_next(timestamp:)

      expect(Subscriptions::ActivateService).to have_received(:call!)
        .with(subscription: next_subscription, timestamp: Time.zone.at(timestamp))
    end

    it "returns the activated subscription in the result" do
      result = terminate_service.terminate_and_start_next(timestamp:)

      expect(result).to be_success
      expect(result.subscription).to eq(next_subscription)
    end

    context "when there is no next subscription" do
      let(:next_subscription) { nil }

      it "does not delegate to ActivateService" do
        terminate_service.terminate_and_start_next(timestamp:)

        expect(Subscriptions::ActivateService).not_to have_received(:call!)
      end
    end

    context "when the next subscription is not pending" do
      let(:next_subscription) do
        create(:subscription, previous_subscription_id: subscription.id, status: :active)
      end

      it "does not delegate to ActivateService" do
        terminate_service.terminate_and_start_next(timestamp:)

        expect(Subscriptions::ActivateService).not_to have_received(:call!)
      end
    end

    context "when ActivateService fails" do
      let(:activation_result) do
        Subscriptions::ActivateService::Result.new.tap do |result|
          result.record_validation_failure!(record: next_subscription)
        end
      end

      before do
        allow(Subscriptions::ActivateService).to receive(:call!) { activation_result.raise_if_error! }
      end

      it "lets the error propagate so the job can retry" do
        expect { terminate_service.terminate_and_start_next(timestamp:) }
          .to raise_error(BaseService::FailedResult)
      end
    end
  end
end
