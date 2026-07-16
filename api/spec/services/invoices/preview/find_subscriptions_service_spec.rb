# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::Preview::FindSubscriptionsService do
  describe ".call" do
    subject(:result) { described_class.call(subscriptions:) }

    let(:subscriptions_result) { result.subscriptions }

    context "when subscriptions are missing" do
      let(:subscriptions) { [] }

      it "fails with subscription not found error" do
        expect(result).to be_failure
        expect(result.error.error_code).to eq("subscription_not_found")
      end
    end

    context "when subscriptions are present" do
      let(:organization) { create(:organization) }
      let(:customer) { create(:customer, organization:) }

      context "when subscriptions has no next subscription" do
        let(:subscriptions) { create_pair(:subscription, organization:, customer:) }

        it "returns the subscriptions as is" do
          expect(result).to be_success
          expect(subscriptions_result).to match_array subscriptions
        end

        it "does not persist any changes to the subscriptions" do
          expect { subject }.not_to change { subscriptions.map { |s| s.reload.attributes } }
        end
      end

      context "when subscription is pending" do
        let(:subscriptions) { [create(:subscription, organization:, customer:, status: :pending)] }

        it "returns the duplicate of subscription" do
          expect(result).to be_success
          expect(subscriptions_result.size).to eq(1)
          expect(subscriptions_result.first.status.to_s).to eq("active")
          expect(subscriptions_result.first.persisted?).to eq(false)
          expect(subscriptions_result.first.external_id).to eq(subscriptions.first.external_id)
        end

        it "does not change original subscription" do
          expect(result).to be_success
          expect(subscriptions.first.reload.status.to_s).to eq("pending")
          expect(subscriptions.first.reload.persisted?).to eq(true)
        end
      end

      context "when subscription has a next subscription" do
        let(:current_plan) { create(:plan, organization:, pay_in_advance: true) }
        let(:next_plan) { create(:plan, organization:, pay_in_advance:, amount_cents:) }
        let!(:subscription) { create(:subscription, plan: current_plan, customer:, organization:, next_subscriptions: [next_subscription]) }
        let!(:next_subscription) { create(:subscription, :pending, plan: next_plan, customer:, organization:) }

        let(:subscriptions) { [subscription] }

        before { travel_to Time.zone.parse("05-02-2025 12:34:56") }

        context "when next plan is pay in advance" do
          let(:pay_in_advance) { true }

          context "when next plan is same price or more expensive (upgrade)" do
            let(:amount_cents) { current_plan.amount_cents + 100 }

            it "returns the subscriptions as is" do
              expect(result).to be_success
              expect(subscriptions_result).to match_array subscriptions
            end

            it "does not persist any changes to the subscriptions" do
              expect { subject }.to not_change { subscription.reload.attributes }.and(not_change { next_subscription.reload.attributes })
            end
          end

          context "when next plan is cheaper (downgrade)" do
            let(:amount_cents) { current_plan.amount_cents - 100 }
            let(:end_of_period) { Time.zone.parse("01-03-2025").end_of_day }

            it "returns array containing terminated current and adjusted next subscription" do
              expect(result).to be_success
              expect(subscriptions_result.count).to eq(2)

              expect(subscriptions_result.first).to have_attributes(
                id: subscription.id,
                status: "terminated",
                terminated_at: end_of_period
              )

              expect(subscriptions_result.second).to have_attributes(
                id: next_subscription.id,
                status: "active",
                started_at: end_of_period.beginning_of_day
              )
            end

            it "does not persist any changes to the subscriptions" do
              expect { subject }.to not_change { subscription.reload.attributes }.and(not_change { next_subscription.reload.attributes })
            end
          end
        end

        context "when next plan is pay in arrears" do
          let(:pay_in_advance) { false }

          context "when next plan is same price or more expensive (upgrade)" do
            let(:amount_cents) { current_plan.amount_cents + 100 }

            it "returns the subscriptions as is" do
              expect(result).to be_success
              expect(subscriptions_result).to match_array subscriptions
            end

            it "does not persist any changes to the subscriptions" do
              expect { subject }.to not_change { subscription.reload.attributes }
                .and(not_change { next_subscription.reload.attributes })
            end
          end

          context "when next plan is cheaper (downgrade)" do
            let(:amount_cents) { current_plan.amount_cents - 100 }
            let(:end_of_period) { Time.zone.parse("01-03-2025").end_of_day }

            it "returns array containing only terminated current subscription" do
              expect(result).to be_success
              expect(subscriptions_result.count).to eq(1)

              expect(subscriptions_result.first).to have_attributes(
                id: subscription.id,
                status: "terminated",
                terminated_at: end_of_period
              )
            end

            it "does not persist any changes to the subscriptions" do
              expect { subject }.to not_change { subscription.reload.attributes }.and(not_change { next_subscription.reload.attributes })
            end
          end
        end
      end
    end
  end
end
