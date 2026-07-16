# frozen_string_literal: true

require "rails_helper"

RSpec.describe LifetimeUsages::UsageThresholds::CheckService do
  subject(:service) { described_class.new(lifetime_usage:, progressive_billed_amount:) }

  let(:lifetime_usage) { create(:lifetime_usage, subscription:, historical_usage_amount_cents:, recalculate_current_usage:, recalculate_invoiced_usage:) }
  let(:progressive_billed_amount) { 0 }
  let(:recalculate_current_usage) { true }
  let(:recalculate_invoiced_usage) { true }
  let(:subscription) { create(:subscription, customer_id: customer.id) }
  let(:organization) { subscription.organization }
  let(:customer) { create(:customer) }
  let(:historical_usage_amount_cents) { 0 }

  def create_thresholds(subscription, amounts:, attach_to:, recurring: nil)
    model = if attach_to == :subscription
      subscription
    elsif attach_to == :plan
      subscription.plan
    else
      raise "invalid attach_to: #{attach_to}"
    end
    amounts.each do |amount|
      model.usage_thresholds.create!(amount_cents: amount, organization:)
    end
    if recurring
      model.usage_thresholds.create!(amount_cents: recurring, recurring: true, organization:)
    end
  end

  def validate_thresholds(mapping)
    mapping.each do |(invoiced, current), expected_threshold_amounts|
      lifetime_usage.invoiced_usage_amount_cents = invoiced
      lifetime_usage.current_usage_amount_cents = current
      result = service.call

      expect(result.passed_thresholds.map(&:amount_cents)).to eq(expected_threshold_amounts), "invoiced:#{invoiced} current:#{current} expected_thresholds: #{expected_threshold_amounts} got: #{result.passed_thresholds.map(&:amount_cents)}"
    end
  end

  # TODO: usage_thresholds remove loop to always attach to sub
  [:subscription, :plan].each do |attach_to|
    context "without progressive_billed_amount" do
      context "without recurring thresholds" do
        context "with no fixed thresholds" do
          before do
            create_thresholds(subscription, amounts: [], attach_to:)
          end

          it "calculates the passed thresholds correctly" do
            validate_thresholds({
              [0, 7] => [],
              [0, 10] => [],
              [9, 2] => [],
              [11, 1] => [],
              [11, 10] => []
            })
          end
        end

        context "with 1 fixed threshold" do
          before do
            create_thresholds(subscription, amounts: [10], attach_to:)
          end

          it "calculates the passed thresholds correctly" do
            validate_thresholds({
              [0, 7] => [],
              [0, 10] => [10],
              [9, 2] => [10],
              [11, 1] => [],
              [11, 10] => []
            })
          end
        end

        context "with multiple fixed thresholds" do
          before do
            create_thresholds(subscription, amounts: [10, 20, 31, 40], attach_to:)
          end

          it "calculates the passed thresholds correctly" do
            validate_thresholds({
              [0, 7] => [],
              [0, 10] => [10],
              [0, 31] => [10, 20, 31],
              [9, 2] => [10],
              [9, 20] => [10, 20],
              [9, 31] => [10, 20, 31, 40],
              [11, 1] => [],
              [11, 10] => [20],
              [21, 20] => [31, 40],
              [40, 2] => [],
              [50, 0] => []
            })
          end
        end
      end

      context "with recurring thresholds" do
        context "with no fixed thresholds" do
          before do
            create_thresholds(subscription, amounts: [], recurring: 10, attach_to:)
          end

          it "calculates the passed thresholds correctly" do
            validate_thresholds({
              [0, 7] => [],
              [0, 10] => [10],
              [9, 2] => [10],
              [11, 1] => [],
              [11, 8] => [],
              [11, 9] => [10],
              [11, 10] => [10],
              [11, 20] => [10],
              [202, 7] => [],
              [202, 8] => [10]
            })
          end
        end

        context "with 1 fixed threshold" do
          before do
            create_thresholds(subscription, amounts: [10], recurring: 5, attach_to:)
          end

          it "calculates the passed thresholds correctly" do
            validate_thresholds({
              [0, 7] => [],
              [0, 10] => [10],
              [0, 15] => [10, 5],
              [0, 20] => [10, 5],
              [9, 2] => [10],
              [9, 6] => [10, 5],
              [9, 20] => [10, 5],
              [11, 3] => [],
              [11, 4] => [5],
              [11, 20] => [5]
            })
          end
        end

        context "with multiple fixed thresholds" do
          before do
            create_thresholds(subscription, amounts: [10, 20, 31, 40], recurring: 5, attach_to:)
          end

          it "calculates the passed thresholds correctly" do
            validate_thresholds({
              [0, 7] => [],
              [0, 10] => [10],
              [0, 31] => [10, 20, 31],
              [0, 44] => [10, 20, 31, 40],
              [0, 45] => [10, 20, 31, 40, 5],
              [9, 2] => [10],
              [9, 20] => [10, 20],
              [9, 31] => [10, 20, 31, 40],
              [9, 37] => [10, 20, 31, 40, 5],
              [11, 1] => [],
              [11, 10] => [20],
              [21, 20] => [31, 40],
              [21, 24] => [31, 40, 5],
              [40, 2] => [],
              [40, 5] => [5],
              [41, 4] => [5],
              [49, 1] => [5],
              [50, 0] => [],
              [50, 5] => [5]
            })
          end
        end
      end
    end

    context "with progressive_billed_amount set to 10" do
      let(:progressive_billed_amount) { 10 }

      context "without recurring thresholds" do
        context "with no fixed thresholds" do
          before do
            create_thresholds(subscription, amounts: [], attach_to:)
          end

          it "calculates the passed thresholds correctly" do
            validate_thresholds({
              [0, 7] => [],
              [0, 10] => [],
              [9, 2] => [],
              [11, 1] => [],
              [11, 10] => []
            })
          end
        end

        context "with 1 fixed threshold" do
          before do
            create_thresholds(subscription, amounts: [10], attach_to:)
          end

          it "calculates the passed thresholds correctly" do
            validate_thresholds({
              [9, 2] => [],
              [9, 20] => [],
              [11, 10] => [],
              [11, 20] => []
            })
          end
        end

        context "with multiple fixed thresholds" do
          before do
            create_thresholds(subscription, amounts: [10, 20, 31, 40], attach_to:)
          end

          it "calculates the passed thresholds correctly" do
            validate_thresholds({
              [0, 10] => [],
              [0, 31] => [20, 31],
              [9, 10] => [],
              [9, 12] => [20],
              [9, 20] => [20],
              [9, 31] => [20, 31, 40],
              [11, 11] => [],
              [11, 20] => [31],
              [21, 20] => [40],
              [30, 12] => [],
              [50, 10] => []
            })
          end
        end
      end

      context "with recurring thresholds" do
        context "with no fixed thresholds" do
          before do
            create_thresholds(subscription, amounts: [], recurring: 10, attach_to:)
          end

          it "calculates the passed thresholds correctly" do
            validate_thresholds({
              [0, 10] => [],
              [11, 10] => [],
              [11, 19] => [10],
              [202, 17] => [],
              [202, 18] => [10],
              [202, 28] => [10]
            })
          end
        end

        context "with 1 fixed threshold" do
          before do
            create_thresholds(subscription, amounts: [10], recurring: 5, attach_to:)
          end

          it "calculates the passed thresholds correctly" do
            validate_thresholds({
              [0, 7] => [],
              [0, 10] => [],
              [0, 15] => [5],
              [0, 20] => [5],
              [9, 2] => [],
              [9, 6] => [],
              [9, 16] => [5],
              [11, 3] => [],
              [11, 4] => [],
              [11, 14] => [5],
              [11, 24] => [5]
            })
          end
        end

        context "with multiple fixed thresholds" do
          before do
            create_thresholds(subscription, amounts: [10, 20, 31, 40], recurring: 5, attach_to:)
          end

          it "calculates the passed thresholds correctly" do
            validate_thresholds({
              [0, 7] => [],
              [0, 10] => [],
              [0, 31] => [20, 31],
              [0, 44] => [20, 31, 40],
              [0, 45] => [20, 31, 40, 5],
              [9, 2] => [],
              [9, 20] => [20],
              [9, 31] => [20, 31, 40],
              [9, 37] => [20, 31, 40, 5],
              [11, 1] => [],
              [11, 10] => [],
              [20, 20] => [31, 40],
              [21, 20] => [40],
              [21, 24] => [40, 5],
              [40, 14] => [],
              [40, 15] => [5],
              [41, 14] => [5],
              [49, 1] => [],
              [49, 11] => [5],
              [50, 5] => [],
              [50, 15] => [5]
            })
          end
        end
      end
    end

    context "with historical_usage_amount_cents" do
      let(:historical_usage_amount_cents) { 11 }

      context "with multiple fixed thresholds" do
        before do
          create_thresholds(subscription, amounts: [10, 20, 31, 40], attach_to:)
        end

        it "calculates the passed thresholds correctly" do
          validate_thresholds({
            [0, 7] => [],
            [0, 9] => [20],
            [0, 10] => [20],
            [9, 0] => [],
            [0, 31] => [20, 31, 40],
            [8, 2] => [20],
            [8, 20] => [20, 31],
            [8, 31] => [20, 31, 40],
            [11, 1] => [],
            [11, 10] => [31],
            [21, 20] => [40],
            [40, 2] => [],
            [50, 0] => []
          })
        end
      end
    end
  end
end
