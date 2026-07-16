# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::Preview::BuildSubscriptionService do
  describe ".call" do
    subject(:result) { described_class.call(customer:, params:) }

    let(:subscriptions) { result.subscriptions }

    context "when customer is missing" do
      let(:customer) { nil }
      let(:params) { {} }

      it "fails with customer not found error" do
        expect(result).to be_failure
        expect(result.error.error_code).to eq("customer_not_found")
      end

      it "does not create any subscription" do
        expect { subject }.not_to change(Subscription, :count)
      end
    end

    context "when customer is present" do
      let(:customer) { create(:customer) }

      context "when plan matching code exists in the customer's organization" do
        let(:plan) { create(:plan, organization: customer.organization) }

        let(:params) do
          {
            plan_code: plan&.code,
            billing_time:,
            subscription_at: subscription_at&.iso8601
          }
        end

        before do
          create(:plan, organization: customer.organization, code: plan.code, parent: plan)
          plan.touch # rubocop:disable Rails/SkipsModelValidations
        end

        context "when valid billing time and subscribed at are provided" do
          let(:billing_time) { Subscription::BILLING_TIME.sample.to_s }
          let(:subscription_at) { generate(:past_date) }

          let(:expected_attributes) do
            {
              billing_time:,
              plan:,
              customer:,
              subscription_at: subscription_at.change(usec: 0),
              started_at: subscription_at.change(usec: 0)
            }
          end

          it "returns array containing new subscription with provided inputs" do
            expect(result).to be_success
            expect(subscriptions).to contain_exactly Subscription

            expect(subscriptions.first)
              .to be_new_record
              .and have_attributes(expected_attributes)
          end

          it "does not create any subscription" do
            expect { subject }.not_to change(Subscription, :count)
          end
        end

        context "when invalid or empty billing time and subscribed at are provided" do
          let(:billing_time) { "non-existing-time" }
          let(:subscription_at) { nil }

          let(:expected_attributes) do
            {
              billing_time: "calendar",
              plan:,
              customer:,
              subscription_at: Time.current,
              started_at: Time.current
            }
          end

          before { freeze_time }

          it "returns array containing new subscription with defaults" do
            expect(result).to be_success
            expect(subscriptions).to contain_exactly Subscription

            expect(subscriptions.first)
              .to be_new_record
              .and have_attributes(expected_attributes)
          end

          it "does not create any subscription" do
            expect { subject }.not_to change(Subscription, :count)
          end
        end
      end

      context "when plan matching code does not exist in the customer's organization" do
        let(:params) { {plan_code: create(:plan).code} }

        it "fails with plan not found error" do
          expect(result).to be_failure
          expect(result.error.error_code).to eq("plan_not_found")
        end

        it "does not create any subscription" do
          expect { subject }.not_to change(Subscription, :count)
        end
      end

      context "when a billing_entity is provided" do
        subject(:result) { described_class.call(customer:, params:, billing_entity:) }

        let(:plan) { create(:plan, organization: customer.organization) }
        let(:other_billing_entity) { create(:billing_entity, organization: customer.organization) }
        let(:params) { {plan_code: plan.code} }

        context "when multi_entity_billing flag is disabled" do
          let(:billing_entity) { other_billing_entity }

          it "does not assign an explicit billing entity on the subscription" do
            expect(result).to be_success
            expect(subscriptions.first.billing_entity_id).to be_nil
          end
        end

        context "when multi_entity_billing flag is enabled" do
          before { customer.organization.enable_feature_flag!(:multi_entity_billing) }

          context "when the billing entity differs from the customer default" do
            let(:billing_entity) { other_billing_entity }

            it "assigns the billing entity on the subscription" do
              expect(result).to be_success
              expect(subscriptions.first.billing_entity_id).to eq(other_billing_entity.id)
            end
          end

          context "when the billing entity matches the customer default" do
            let(:billing_entity) { customer.billing_entity }

            it "leaves the subscription's billing_entity_id nil so it inherits at billing time" do
              expect(result).to be_success
              expect(subscriptions.first.billing_entity_id).to be_nil
            end
          end
        end
      end
    end
  end
end
