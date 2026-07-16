# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::Preview::SubscriptionPlanChangeService do
  describe ".call" do
    subject(:result) { described_class.call(current_subscription:, target_plan_code:) }

    let(:subscriptions) { result.subscriptions }

    context "when current subscription is missing" do
      let(:current_subscription) { nil }
      let(:target_plan_code) { nil }

      it "fails with subscription not found error" do
        expect(result).to be_failure
        expect(result.error.error_code).to eq("subscription_not_found")
      end
    end

    context "when plan matching code does not exist" do
      let(:current_subscription) { create(:subscription) }
      let(:target_plan_code) { "non-existing-code" }

      it "fails with plan not found error" do
        expect(result).to be_failure
        expect(result.error.error_code).to eq("plan_not_found")
      end
    end

    context "when current subscription and matching plan are present" do
      let!(:current_subscription) { create(:subscription, plan: current_plan, organization:) }
      let(:current_plan) { create(:plan, organization:) }
      let(:organization) { create(:organization) }
      let(:target_plan_code) { target_plan.code }

      context "when target plan is the same as current subscription's plan" do
        let(:target_plan) { current_plan }

        it "fails with invalid target plan error" do
          expect(result).to be_failure

          expect(result.error.messages)
            .to match(base: ["new_plan_should_be_different_from_existing_plan"])
        end

        it "does not persist any changes to the current subscription" do
          expect { subject }.not_to change { current_subscription.reload.attributes }
        end

        it "does not create any subscription" do
          expect { subject }.not_to change(Subscription, :count)
        end
      end

      context "when target plan is not the same as current subscription's plan" do
        let(:target_plan) { create(:plan, organization:, pay_in_advance:, amount_cents:) }

        before do
          travel_to Time.zone.parse("05-02-2025 12:34:56")
          create(:plan, organization:, code: target_plan.code, parent: target_plan)
          target_plan.touch # rubocop:disable Rails/SkipsModelValidations
        end

        context "when target plan is pay in advance" do
          let(:pay_in_advance) { true }

          context "when target plan is same price or more expensive" do
            let(:amount_cents) { current_plan.amount_cents }

            it "returns array containing terminated current and new subscriptions" do
              expect(result).to be_success
              expect(subscriptions).to match_array [current_subscription, Subscription]

              expect(subscriptions.first).to have_attributes(
                status: "terminated",
                next_subscription: Subscription,
                terminated_at: Time.current
              )

              expect(subscriptions.second)
                .to be_new_record
                .and have_attributes(status: "active", started_at: Time.current, name: target_plan.name, plan: target_plan)
            end

            it "does not persist any changes to the current subscription" do
              expect { subject }.not_to change { current_subscription.reload.attributes }
            end

            it "does not create any subscription" do
              expect { subject }.not_to change(Subscription, :count)
            end
          end

          context "when target plan is cheaper" do
            let(:amount_cents) { current_plan.amount_cents - 1 }
            let(:start_of_next_billing_period) { Time.zone.parse("01-03-2025").end_of_day }

            it "returns array containing terminated current and new subscriptions" do
              expect(result).to be_success
              expect(subscriptions).to match_array [current_subscription, Subscription]

              expect(subscriptions.first).to have_attributes(
                status: "terminated",
                next_subscription: Subscription,
                terminated_at: start_of_next_billing_period
              )

              expect(subscriptions.second)
                .to be_new_record
                .and have_attributes(status: "active", started_at: start_of_next_billing_period.beginning_of_day, name: target_plan.name, plan: target_plan)
            end

            it "does not persist any changes to the current subscription" do
              expect { subject }.not_to change { current_subscription.reload.attributes }
            end

            it "does not create any subscription" do
              expect { subject }.not_to change(Subscription, :count)
            end
          end
        end

        context "when target plan is not pay in advance" do
          let(:pay_in_advance) { false }

          context "when target plan is same price or more expensive" do
            let(:amount_cents) { current_plan.amount_cents }

            it "returns array containing terminated current subscription" do
              expect(result).to be_success
              expect(subscriptions).to contain_exactly current_subscription

              expect(subscriptions.first).to have_attributes(
                status: "terminated",
                next_subscription: Subscription,
                terminated_at: Time.current
              )
            end

            it "does not persist any changes to the current subscription" do
              expect { subject }.not_to change { current_subscription.reload.attributes }
            end

            it "does not create any subscription" do
              expect { subject }.not_to change(Subscription, :count)
            end
          end

          context "when target plan is cheaper" do
            let(:amount_cents) { current_plan.amount_cents - 1 }
            let(:start_of_next_billing_period) { Time.zone.parse("01-03-2025").end_of_day }

            it "returns array containing terminated current subscription" do
              expect(result).to be_success
              expect(subscriptions).to contain_exactly current_subscription

              expect(subscriptions.first).to have_attributes(
                status: "terminated",
                next_subscription: Subscription,
                terminated_at: start_of_next_billing_period
              )
            end

            it "does not persist any changes to the current subscription" do
              expect { subject }.not_to change { current_subscription.reload.attributes }
            end

            it "does not create any subscription" do
              expect { subject }.not_to change(Subscription, :count)
            end
          end
        end
      end
    end
  end
end
