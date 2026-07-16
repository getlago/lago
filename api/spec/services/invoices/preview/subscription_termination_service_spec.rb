# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::Preview::SubscriptionTerminationService do
  describe ".call" do
    subject(:result) do
      described_class.call(current_subscription:, terminated_at: terminated_at&.to_s)
    end

    let(:subscriptions) { result.subscriptions }

    context "when current subscription is missing" do
      let(:current_subscription) { nil }
      let(:terminated_at) { nil }

      it "fails with subscription not found error" do
        expect(result).to be_failure
        expect(result.error.error_code).to eq("subscription_not_found")
      end
    end

    context "when current subscription is present" do
      let(:current_subscription) { create(:subscription) }

      context "when termination at is a valid timestamp" do
        context "when timestamp is in the past" do
          let(:terminated_at) { Time.current - 1.second }

          it "fails with past timestamp error" do
            expect(result).to be_failure
            expect(result.error.messages).to match(terminated_at: ["cannot_be_in_past"])
          end

          it "does not persist any changes to the current subscription" do
            expect { subject }.not_to change { current_subscription.reload.attributes }
          end
        end

        context "when timestamp is current time" do
          let(:terminated_at) { Time.current }

          it "fails with past timestamp error" do
            expect(result).to be_failure
            expect(result.error.messages).to match(terminated_at: ["cannot_be_in_past"])
          end

          it "does not persist any changes to the current subscription" do
            expect { subject }.not_to change { current_subscription.reload.attributes }
          end
        end

        context "when timestamp is in future" do
          let(:terminated_at) { Time.current + 1.second }

          it "returns result with subscriptions marked as terminated" do
            expect(result).to be_success
            expect(subscriptions).to contain_exactly current_subscription

            expect(subscriptions.first).to have_attributes(
              terminated_at: terminated_at.change(usec: 0),
              status: "terminated"
            )
          end

          it "does not persist any changes to the current subscription" do
            expect { subject }.not_to change { current_subscription.reload.attributes }
          end
        end
      end

      context "when termination at is not a valid timestamp" do
        let(:terminated_at) { "2025" }

        it "fails with invalid timestamp error" do
          expect(result).to be_failure
          expect(result.error.messages).to match(terminated_at: ["invalid_timestamp"])
        end

        it "does not persist any changes to the current subscription" do
          expect { subject }.not_to change { current_subscription.reload.attributes }
        end
      end
    end
  end
end
