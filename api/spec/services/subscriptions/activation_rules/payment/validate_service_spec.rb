# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::ActivationRules::Payment::ValidateService do
  subject(:validate_service) { described_class.new(result, **args) }

  let(:result) { BaseService::Result.new }
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, customer:, plan:, organization:) }
  let(:rule) { {type: "payment", timeout_hours: 48} }
  let(:payment_method_params) { nil }

  let(:args) do
    {
      rule:,
      payment_method: payment_method_params,
      subscription:,
      customer:
    }
  end

  describe "#valid?" do
    context "with valid payment rule" do
      before { create(:payment_method, customer:, organization:) }

      it { is_expected.to be_valid }
    end

    context "when timeout_hours is absent" do
      let(:rule) { {type: "payment"} }

      before { create(:payment_method, customer:, organization:) }

      it { is_expected.to be_valid }
    end

    context "when timeout_hours is zero" do
      let(:rule) { {type: "payment", timeout_hours: 0} }

      before { create(:payment_method, customer:, organization:) }

      it { is_expected.to be_valid }
    end

    context "when timeout_hours is negative" do
      let(:rule) { {type: "payment", timeout_hours: -1} }

      it "is invalid with value_must_be_positive_or_zero error" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:timeout_hours]).to eq(["value_must_be_positive_or_zero"])
      end
    end

    context "when timeout_hours is not an integer" do
      let(:rule) { {type: "payment", timeout_hours: "abc"} }

      it "is invalid with value_must_be_positive_or_zero error" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:timeout_hours]).to eq(["value_must_be_positive_or_zero"])
      end
    end

    context "when payment_method params are present" do
      context "when payment_method_type is manual" do
        let(:payment_method_params) { {payment_method_type: "manual"} }

        it "is invalid with manual_payment_method_invalid_for_payment_activation_rules error" do
          expect(validate_service).not_to be_valid
          expect(result.error.messages[:customer]).to eq(["manual_payment_method_invalid_for_payment_activation_rules"])
        end
      end

      context "when payment_method_type is provider" do
        let(:payment_method_params) { {payment_method_type: "provider"} }

        context "when customer has a default payment method" do
          before { create(:payment_method, customer:, organization:) }

          it { is_expected.to be_valid }
        end

        context "when customer has no default payment method" do
          it "is invalid with no_default_payment_method error" do
            expect(validate_service).not_to be_valid
            expect(result.error.messages[:customer]).to eq(["no_default_payment_method"])
          end
        end
      end

      context "when payment_method params include a payment_method_id" do
        let(:payment_method) { create(:payment_method, customer:, organization:, is_default: false) }
        let(:payment_method_params) { {payment_method_type: "provider", payment_method_id: payment_method.id} }

        it "is valid when the payment method id is provided" do
          expect(validate_service).to be_valid
        end

        context "when payment_method_id refers to a non-existent payment method" do
          let(:payment_method_params) { {payment_method_type: "provider", payment_method_id: "00000000-0000-0000-0000-000000000000"} }

          it "is invalid with payment_method_not_found error" do
            expect(validate_service).not_to be_valid
            expect(result.error.messages[:customer]).to eq(["payment_method_not_found"])
          end
        end

        context "when payment_method_id belongs to another customer" do
          let(:other_customer) { create(:customer, organization:) }
          let(:payment_method) { create(:payment_method, customer: other_customer, organization:, is_default: false) }

          it "is invalid with payment_method_not_found error" do
            expect(validate_service).not_to be_valid
            expect(result.error.messages[:customer]).to eq(["payment_method_not_found"])
          end
        end

        context "when payment_method_id refers to a soft-deleted payment method" do
          before { payment_method.discard! }

          it "is invalid with payment_method_not_found error" do
            expect(validate_service).not_to be_valid
            expect(result.error.messages[:customer]).to eq(["payment_method_not_found"])
          end
        end
      end
    end

    context "when payment_method params are absent" do
      context "when subscription exists" do
        context "when subscription payment_method_type is manual" do
          let(:subscription) { create(:subscription, customer:, plan:, organization:, payment_method_type: "manual") }

          it "is invalid with manual_payment_method_invalid_for_payment_activation_rules error" do
            expect(validate_service).not_to be_valid
            expect(result.error.messages[:customer]).to eq(["manual_payment_method_invalid_for_payment_activation_rules"])
          end
        end

        context "when subscription payment_method_type is provider" do
          let(:subscription) { create(:subscription, customer:, plan:, organization:, payment_method_type: "provider") }

          context "when customer has a default payment method" do
            before { create(:payment_method, customer:, organization:) }

            it { is_expected.to be_valid }
          end

          context "when subscription has its own payment_method_id" do
            let(:subscription_payment_method) { create(:payment_method, customer:, organization:, is_default: false) }
            let(:subscription) { create(:subscription, customer:, plan:, organization:, payment_method_type: "provider", payment_method: subscription_payment_method) }

            it "is valid even when customer has no default payment method" do
              expect(validate_service).to be_valid
            end

            context "when the subscription payment method is soft-deleted" do
              before { subscription_payment_method.discard! }

              it "is invalid with payment_method_not_found error" do
                expect(validate_service).not_to be_valid
                expect(result.error.messages[:customer]).to eq(["payment_method_not_found"])
              end
            end
          end

          context "when subscription has no payment_method_id and customer has no default payment method" do
            it "is invalid with no_default_payment_method error" do
              expect(validate_service).not_to be_valid
              expect(result.error.messages[:customer]).to eq(["no_default_payment_method"])
            end
          end
        end
      end

      context "when subscription is nil" do
        let(:subscription) { nil }

        context "when customer has a payment provider" do
          let(:customer) { create(:customer, organization:, payment_provider: "stripe") }

          context "when customer has a default payment method" do
            before { create(:payment_method, customer:, organization:) }

            it { is_expected.to be_valid }
          end

          context "when customer has no default payment method" do
            it "is invalid with no_default_payment_method error" do
              expect(validate_service).not_to be_valid
              expect(result.error.messages[:customer]).to eq(["no_default_payment_method"])
            end
          end

          context "when customer has payment methods but none is default" do
            before { create(:payment_method, customer:, organization:, is_default: false) }

            it "is invalid with no_default_payment_method error" do
              expect(validate_service).not_to be_valid
              expect(result.error.messages[:customer]).to eq(["no_default_payment_method"])
            end
          end
        end

        context "when customer has no payment provider" do
          let(:customer) { create(:customer, organization:, payment_provider: nil) }

          it "is invalid with no_linked_payment_provider error" do
            expect(validate_service).not_to be_valid
            expect(result.error.messages[:customer]).to eq(["no_linked_payment_provider"])
          end
        end
      end
    end
  end
end
