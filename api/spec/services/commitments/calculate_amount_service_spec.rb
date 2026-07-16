# frozen_string_literal: true

require "rails_helper"

RSpec.describe Commitments::CalculateAmountService do
  subject(:apply_service) { described_class.new(commitment:, invoice_subscription:) }

  let(:invoice_subscription) do
    create(:invoice_subscription, subscription:, from_datetime:, to_datetime:, timestamp:)
  end

  let(:subscription) { create(:subscription, customer:, plan:, billing_time:, subscription_at:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:, interval:) }
  let(:billing_time) { :calendar }

  describe "call" do
    context "when plan has weekly interval" do
      let(:amount_cents) { 3_000 }
      let(:interval) { :weekly }
      let(:from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
      let(:subscription_at) { DateTime.parse("2024-01-01T00:00:00") }
      let(:to_datetime) { DateTime.parse("2024-01-07T23:59:59") }
      let(:timestamp) { DateTime.parse("2024-01-08T10:00:00") }

      context "when subscription is calendar" do
        let(:billing_time) { :calendar }

        context "when there is no commitment" do
          let(:commitment) { nil }

          it "returns result" do
            result = apply_service.call

            expect(result.commitment_amount_cents).to eq(0)
          end
        end

        context "when a commitment exists for a plan" do
          let(:commitment) { create(:commitment, plan:, amount_cents:) }

          before { commitment }

          it "returns result" do
            result = apply_service.call

            expect(result.commitment_amount_cents).to eq(commitment.amount_cents)
          end
        end
      end

      context "when subscription is anniversary" do
        let(:billing_time) { :anniversary }

        context "when there is no commitment" do
          let(:commitment) { nil }

          it "returns result" do
            result = apply_service.call

            expect(result.commitment_amount_cents).to eq(0)
          end
        end

        context "when a commitment exists for a plan" do
          let(:commitment) { create(:commitment, plan:, amount_cents:) }

          context "when it is full period" do
            it "returns result" do
              result = apply_service.call

              expect(result.commitment_amount_cents).to eq(commitment.amount_cents)
            end
          end

          context "when it is not full period" do
            let(:to_datetime) { DateTime.parse("2024-01-06T23:59:59") }
            let(:timestamp) { DateTime.parse("2024-01-07T10:00:00") }

            it "returns prorated result" do
              result = apply_service.call

              expect(result.commitment_amount_cents).to eq(2_571)
            end
          end
        end
      end
    end

    context "when plan has monthly interval" do
      let(:amount_cents) { 20_000 }
      let(:interval) { :monthly }
      let(:from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
      let(:subscription_at) { DateTime.parse("2024-01-01T00:00:00") }
      let(:to_datetime) { DateTime.parse("2024-01-31T23:59:59") }
      let(:timestamp) { DateTime.parse("2024-02-05T10:00:00") }

      context "when subscription is calendar" do
        let(:billing_time) { :calendar }

        context "when there is no commitment" do
          let(:commitment) { nil }

          it "returns result" do
            result = apply_service.call

            expect(result.commitment_amount_cents).to eq(0)
          end
        end

        context "when a commitment exists for a plan" do
          let(:commitment) { create(:commitment, plan:, amount_cents:) }

          it "returns result" do
            result = apply_service.call

            expect(result.commitment_amount_cents).to eq(commitment.amount_cents)
          end
        end
      end

      context "when subscription is anniversary" do
        let(:billing_time) { :anniversary }

        context "when there is no commitment" do
          let(:commitment) { nil }

          it "returns result" do
            result = apply_service.call

            expect(result.commitment_amount_cents).to eq(0)
          end
        end

        context "when a commitment exists for a plan" do
          let(:commitment) { create(:commitment, plan:, amount_cents:) }

          context "when it is full period" do
            it "returns result" do
              result = apply_service.call

              expect(result.commitment_amount_cents).to eq(commitment.amount_cents)
            end
          end

          context "when it is not full period" do
            let(:to_datetime) { DateTime.parse("2024-01-30T23:59:59") }
            let(:timestamp) { DateTime.parse("2024-02-04T10:00:00") }

            it "returns result" do
              result = apply_service.call

              expect(result.commitment_amount_cents).to eq(19_355)
            end
          end
        end
      end
    end

    context "when plan has quarterly interval" do
      let(:amount_cents) { 40_000 }
      let(:interval) { :quarterly }
      let(:from_datetime) { DateTime.parse("2024-01-01T00:00:00") }
      let(:subscription_at) { DateTime.parse("2024-01-01T00:00:00") }
      let(:to_datetime) { DateTime.parse("2024-03-31T23:59:59") }
      let(:timestamp) { DateTime.parse("2024-04-05T10:00:00") }

      context "when subscription is calendar" do
        let(:billing_time) { :calendar }

        context "when there is no commitment" do
          let(:commitment) { nil }

          it "returns result" do
            result = apply_service.call

            expect(result.commitment_amount_cents).to eq(0)
          end
        end

        context "when a commitment exists for a plan" do
          let(:commitment) { create(:commitment, plan:, amount_cents:) }

          before { commitment }

          it "returns result" do
            result = apply_service.call

            expect(result.commitment_amount_cents).to eq(commitment.amount_cents)
          end
        end
      end

      context "when subscription is anniversary" do
        let(:billing_time) { :anniversary }

        context "when there is no commitment" do
          let(:commitment) { nil }

          it "returns result" do
            result = apply_service.call

            expect(result.commitment_amount_cents).to eq(0)
          end
        end

        context "when a commitment exists for a plan" do
          let(:commitment) { create(:commitment, plan:, amount_cents:) }

          context "when it is full period" do
            it "returns result" do
              result = apply_service.call

              expect(result.commitment_amount_cents).to eq(commitment.amount_cents)
            end
          end

          context "when it is not full period" do
            let(:to_datetime) { DateTime.parse("2024-03-30T23:59:59") }
            let(:timestamp) { DateTime.parse("2024-04-04T10:00:00") }

            it "returns prorated result" do
              result = apply_service.call

              expect(result.commitment_amount_cents).to eq(39_560)
            end
          end
        end
      end
    end

    context "when plan has yearly interval" do
      let(:amount_cents) { 200_000 }
      let(:interval) { :yearly }
      let(:from_datetime) { DateTime.parse("2024-01-15T00:00:00") }
      let(:subscription_at) { DateTime.parse("2024-01-15T00:00:00") }

      context "when subscription is calendar" do
        let(:billing_time) { :calendar }
        let(:to_datetime) { DateTime.parse("2024-12-31T23:59:59") }
        let(:timestamp) { DateTime.parse("2025-01-05T10:00:00") }

        context "when there is no commitment" do
          let(:commitment) { nil }

          it "returns result" do
            result = apply_service.call

            expect(result.commitment_amount_cents).to eq(0)
          end
        end

        context "when a commitment exists for a plan" do
          let(:commitment) { create(:commitment, plan:, amount_cents:) }

          before { commitment }

          it "returns result" do
            result = apply_service.call

            expect(result.commitment_amount_cents).to eq(192_350)
          end
        end
      end

      context "when subscription is anniversary" do
        let(:billing_time) { :anniversary }
        let(:to_datetime) { DateTime.parse("2025-01-14T23:59:59") }
        let(:timestamp) { DateTime.parse("2025-01-19T10:00:00") }

        context "when there is no commitment" do
          let(:commitment) { nil }

          it "returns result" do
            result = apply_service.call

            expect(result.commitment_amount_cents).to eq(0)
          end
        end

        context "when a commitment exists for a plan" do
          let(:commitment) { create(:commitment, plan:, amount_cents:) }

          context "when it is full period" do
            it "returns result" do
              result = apply_service.call

              expect(result.commitment_amount_cents).to eq(commitment.amount_cents)
            end
          end

          context "when it is not full period" do
            let(:to_datetime) { DateTime.parse("2025-01-13T23:59:59") }
            let(:timestamp) { DateTime.parse("2025-01-18T10:00:00") }

            it "returns prorated result" do
              result = apply_service.call

              expect(result.commitment_amount_cents).to eq(199_454)
            end
          end
        end
      end
    end
  end
end
