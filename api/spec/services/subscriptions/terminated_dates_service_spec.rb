# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::TerminatedDatesService do
  subject(:terminated_date_service) { described_class.new(subscription:, invoice:, date_service:, match_invoice_subscription:) }

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:, interval: :monthly) }
  let(:subscription_at) { DateTime.parse("02 Feb 2021") }
  let(:started_at) { subscription_at }
  let(:billing_date) { DateTime.parse("2022-03-07 04:20:46.011") }
  let(:invoice) { create(:invoice, organization:, customer: subscription.customer) }
  let(:match_invoice_subscription) { true }

  let(:invoice_subscription) do
    create(
      :invoice_subscription,
      invoice:,
      subscription:,
      timestamp: billing_date
    )
  end

  let(:date_service) { instance_double(Subscriptions::DatesService) }

  before do
    invoice_subscription
  end

  describe "#call" do
    subject(:service_call) { terminated_date_service.call }

    let(:service_current_usage) { service_call.__send__(:current_usage) }

    context "when subscription is terminated" do
      let(:subscription) do
        create(
          :subscription,
          :terminated,
          plan:,
          subscription_at:,
          billing_time: :calendar,
          started_at:
        )
      end

      context "when termination date is started_at date" do
        let(:billing_date) { started_at }

        it "returns the same dates service" do
          expect(service_call).to eq(date_service)
        end
      end

      context "when termination date is earlier than charges_to_datetime date" do
        let(:billing_date) { DateTime.parse("2022-06-01 04:20:46.011") }

        let(:new_dates_service) do
          instance_double(
            Subscriptions::DatesService,
            charges_to_datetime: DateTime.parse("2022-06-02 04:20:46.011")
          )
        end

        before do
          allow(Subscriptions::DatesService)
            .to receive(:new_instance)
            .and_return(new_dates_service)
        end

        it "calls Subscriptions::DatesService.new_instance" do
          service_call

          expect(Subscriptions::DatesService)
            .to have_received(:new_instance)
            .with(kind_of(Subscription), billing_date - 1.day, current_usage: true)
        end

        it "returns a new dates service" do
          expect(service_call).to eq(date_service)
        end
      end

      context "when there are more than one day between charges_to_datetime and termination date" do
        let(:billing_date) { DateTime.parse("2022-06-03 04:20:46.011") }

        let(:new_dates_service) do
          instance_double(
            Subscriptions::DatesService,
            charges_to_datetime: DateTime.parse("2022-06-01 04:20:46.011")
          )
        end

        before do
          allow(Subscriptions::DatesService)
            .to receive(:new_instance)
            .and_return(new_dates_service)
        end

        it "calls Subscriptions::DatesService.new_instance" do
          service_call

          expect(Subscriptions::DatesService)
            .to have_received(:new_instance)
            .with(kind_of(Subscription), billing_date - 1.day, current_usage: true)
        end

        it "returns the same dates service" do
          expect(service_call).to eq(date_service)
        end
      end

      context "when termination date is earlier than fixed_charges_to_datetime date" do
        let(:billing_date) { DateTime.parse("2022-06-03 04:20:46.011") }

        let(:new_dates_service) do
          instance_double(
            Subscriptions::DatesService,
            charges_to_datetime: DateTime.parse("2022-06-03 04:20:46.011"),
            fixed_charges_to_datetime: DateTime.parse("2022-06-05 04:20:46.011")
          )
        end

        before do
          allow(Subscriptions::DatesService)
            .to receive(:new_instance)
            .and_return(new_dates_service)
        end

        it "calls Subscriptions::DatesService.new_instance" do
          service_call

          expect(Subscriptions::DatesService)
            .to have_received(:new_instance)
            .with(kind_of(Subscription), billing_date - 1.day, current_usage: true)
        end

        it "returns a new dates service" do
          expect(service_call).to eq(date_service)
        end
      end

      context "when there is more than one day between fixed_charges_to_datetime and termination date" do
        let(:billing_date) { DateTime.parse("2022-06-03 04:20:46.011") }

        let(:new_dates_service) do
          instance_double(
            Subscriptions::DatesService,
            charges_to_datetime: DateTime.parse("2022-06-03 04:20:46.011"),
            fixed_charges_to_datetime: DateTime.parse("2022-06-02 04:20:46.011")
          )
        end

        before do
          allow(Subscriptions::DatesService)
            .to receive(:new_instance)
            .and_return(new_dates_service)
        end

        it "calls Subscriptions::DatesService.new_instance" do
          service_call

          expect(Subscriptions::DatesService)
            .to have_received(:new_instance)
            .with(kind_of(Subscription), billing_date - 1.day, current_usage: true)
        end

        it "returns the same dates service" do
          expect(service_call).to eq(date_service)
        end
      end

      context "when not matching invoice subscription" do
        let(:match_invoice_subscription) { false }
        let(:billing_date) { DateTime.parse("2022-06-01 04:20:46.011") }

        let(:new_dates_service_1) do
          instance_double(
            Subscriptions::DatesService,
            charges_to_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
            fixed_charges_to_datetime: DateTime.parse("2022-06-01 04:20:46.011")
          )
        end

        let(:new_dates_service_2) do
          instance_double(
            Subscriptions::DatesService,
            charges_to_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
            fixed_charges_to_datetime: DateTime.parse("2022-06-01 04:20:46.011")
          )
        end

        before do
          allow(Subscriptions::DatesService)
            .to receive(:new_instance)
            .with(kind_of(Subscription), billing_date - 1.day, current_usage: true)
            .and_return(new_dates_service_1)

          allow(Subscriptions::DatesService)
            .to receive(:new_instance)
            .with(kind_of(Subscription), billing_date, current_usage: false)
            .and_return(new_dates_service_2)
        end

        it "returns a new dates service" do
          expect(service_call).to eq(new_dates_service_2)
        end
      end

      context "when matching invoice subscription" do
        let(:match_invoice_subscription) { true }
        let(:billing_date) { DateTime.parse("2022-06-01 04:20:46.011") }

        let(:new_dates_service_1) do
          instance_double(
            Subscriptions::DatesService,
            charges_to_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
            fixed_charges_to_datetime: DateTime.parse("2022-06-01 04:20:46.011")
          )
        end

        let(:new_dates_service_2) do
          instance_double(
            Subscriptions::DatesService,
            from_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
            to_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
            charges_from_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
            charges_to_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
            fixed_charges_from_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
            fixed_charges_to_datetime: DateTime.parse("2022-06-01 04:20:46.011")
          )
        end

        before do
          allow(Subscriptions::DatesService)
            .to receive(:new_instance)
            .with(kind_of(Subscription), billing_date - 1.day, current_usage: true)
            .and_return(new_dates_service_1)

          allow(Subscriptions::DatesService)
            .to receive(:new_instance)
            .with(kind_of(Subscription), billing_date, current_usage: false)
            .and_return(new_dates_service_2)
        end

        context "when there is not matching invoice subscription" do
          it "returns a new dates service" do
            expect(service_call).to eq(new_dates_service_2)
          end
        end

        it "returns the same dates service" do
          create(
            :invoice_subscription,
            subscription:,
            recurring: true,
            from_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
            to_datetime: DateTime.parse("2022-06-01 04:20:46.011")
          )

          expect(service_call).to eq(date_service)
        end

        context "when plan splits charges in monthly intervals" do
          before do
            allow(plan).to receive(:charges_billed_in_monthly_split_intervals?).and_return(true)
          end

          it "returns a new dates service" do
            create(
              :invoice_subscription,
              subscription:,
              recurring: true,
              from_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
              to_datetime: DateTime.parse("2022-06-01 04:20:46.011")
            )

            expect(service_call).to eq(new_dates_service_2)
          end

          context "when there is a matching invoice subscription" do
            before do
              create(
                :invoice_subscription,
                subscription:,
                recurring: true,
                from_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
                to_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
                charges_from_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
                charges_to_datetime: DateTime.parse("2022-06-01 04:20:46.011")
              )
            end

            it "returns the same dates service" do
              expect(service_call).to eq(date_service)
            end
          end
        end

        context "when plan splits fixed charges in monthly intervals" do
          before do
            allow(plan).to receive(:fixed_charges_billed_in_monthly_split_intervals?).and_return(true)
          end

          it "returns a new dates service" do
            create(
              :invoice_subscription,
              subscription:,
              recurring: true,
              from_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
              to_datetime: DateTime.parse("2022-06-01 04:20:46.011")
            )

            expect(service_call).to eq(new_dates_service_2)
          end

          context "when there is a matching invoice subscription" do
            before do
              create(
                :invoice_subscription,
                subscription:,
                recurring: true,
                from_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
                to_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
                fixed_charges_from_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
                fixed_charges_to_datetime: DateTime.parse("2022-06-01 04:20:46.011")
              )
            end

            it "returns the same dates service" do
              expect(service_call).to eq(date_service)
            end
          end
        end

        context "when plan splits both charges and fixed charges in monthly intervals" do
          before do
            allow(plan).to receive(:charges_billed_in_monthly_split_intervals?).and_return(true)
            allow(plan).to receive(:fixed_charges_billed_in_monthly_split_intervals?).and_return(true)
          end

          it "returns a new dates service" do
            create(
              :invoice_subscription,
              subscription:,
              recurring: true,
              from_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
              to_datetime: DateTime.parse("2022-06-01 04:20:46.011")
            )

            create(
              :invoice_subscription,
              subscription:,
              recurring: true,
              from_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
              to_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
              charges_from_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
              charges_to_datetime: DateTime.parse("2022-06-01 04:20:46.011")
            )

            create(
              :invoice_subscription,
              subscription:,
              recurring: true,
              from_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
              to_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
              fixed_charges_from_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
              fixed_charges_to_datetime: DateTime.parse("2022-06-01 04:20:46.011")
            )

            expect(service_call).to eq(new_dates_service_2)
          end

          context "when there is a matching invoice subscription" do
            before do
              create(
                :invoice_subscription,
                subscription:,
                recurring: true,
                from_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
                to_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
                charges_from_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
                charges_to_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
                fixed_charges_from_datetime: DateTime.parse("2022-06-01 04:20:46.011"),
                fixed_charges_to_datetime: DateTime.parse("2022-06-01 04:20:46.011")
              )
            end

            it "returns the same dates service" do
              expect(service_call).to eq(date_service)
            end
          end
        end
      end

      context "when pay in advance subscription is yearly with monthly charges in advance and dates_service does not have fixed_charges_boundaries" do
        let(:plan) { create(:plan, organization:, interval: :yearly, bill_charges_monthly: true, pay_in_advance: true) }
        let(:subscription) { create(:subscription, :terminated, plan:, subscription_at:, billing_time: :anniversary, started_at:) }
        let(:subscription_at) { DateTime.parse("02 Feb 2021") }
        let(:started_at) { subscription_at }
        # in the middle of the yearly billing period fixed_charges won't be charged, so the
        # date service won't return fixed_charges boundaries
        let(:billing_date) { DateTime.parse("2022-06-02 00:01:46.011") }

        it "returns the new date service because subscription is yearly, but the charges were monthly" do
          expect(service_call).not_to eq(date_service)
        end
      end
    end

    context "when subscription has next subscription" do
      let(:subscription) do
        create(:subscription, plan:, subscription_at:, billing_time: :anniversary, started_at:)
      end

      let(:next_subscription) do
        create(
          :subscription,
          :pending,
          previous_subscription: subscription,
          plan:,
          subscription_at:,
          billing_time: :anniversary,
          started_at: nil
        )
      end

      before do
        next_subscription
      end

      it "returns the same dates service" do
        expect(service_call).to eq(date_service)
      end
    end

    context "when subscription is not terminated" do
      let(:subscription) do
        create(:subscription, plan:, subscription_at:, billing_time: :anniversary, started_at:)
      end

      it "returns the same dates service" do
        expect(service_call).to eq(date_service)
      end
    end
  end
end
