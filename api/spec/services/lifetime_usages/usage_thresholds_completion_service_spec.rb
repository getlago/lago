# frozen_string_literal: true

require "rails_helper"

RSpec.describe LifetimeUsages::UsageThresholdsCompletionService do
  subject(:result) { described_class.call(lifetime_usage:) }

  let(:lifetime_usage) { create(:lifetime_usage, subscription:, organization:, current_usage_amount_cents:) }
  let(:current_usage_amount_cents) { 0 }

  let(:plan) { create(:plan) }
  let(:organization) { plan.organization }

  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, plan:, customer:) }

  def create_threshold(attached_to:, **factory_args)
    if attached_to == :subscription
      create(:usage_threshold, :for_subscription, subscription:, **factory_args)
    elsif attached_to == :plan
      create(:usage_threshold, plan:, **factory_args)
    end
  end

  it "computes the usage thresholds" do
    expect(result.usage_thresholds).to be_empty
  end

  # TODO: usage_thresholds remove loop to always attach to sub
  [:subscription, :plan].each do |attached_to|
    context "with a usage threshold" do
      let(:usage_threshold) { create_threshold(attached_to:, amount_cents: 100) }

      before do
        usage_threshold
      end

      it "computes the usage thresholds" do
        thresholds = result.usage_thresholds
        expect(thresholds.size).to eq(1)
        threshold = thresholds.first

        expect(threshold[:usage_threshold]).to eq(usage_threshold)
        expect(threshold[:amount_cents]).to eq(usage_threshold.amount_cents)
        expect(threshold[:completion_ratio]).to be_zero
        expect(threshold[:reached_at]).to be_nil
      end

      context "with a lifetime_usage" do
        let(:current_usage_amount_cents) { 23 }

        it "computes the usage thresholds" do
          thresholds = result.usage_thresholds
          expect(thresholds.size).to eq(1)
          threshold = thresholds.first

          expect(threshold[:usage_threshold]).to eq(usage_threshold)
          expect(threshold[:amount_cents]).to eq(usage_threshold.amount_cents)
          expect(threshold[:completion_ratio]).to eq(0.23)
          expect(threshold[:reached_at]).to be_nil
        end
      end
    end

    context "with a past threshold" do
      let(:usage_threshold1) { create_threshold(attached_to:, amount_cents: 100) }
      let(:usage_threshold2) { create_threshold(attached_to:, amount_cents: 200) }

      let(:applied_usage_threshold) { create(:applied_usage_threshold, usage_threshold: usage_threshold1, invoice:) }

      let(:invoice) { create(:invoice, organization:, customer:) }
      let(:invoice_subscription) { create(:invoice_subscription, invoice:, subscription:) }

      let(:current_usage_amount_cents) { 120 }

      before do
        usage_threshold1
        usage_threshold2

        invoice_subscription
        applied_usage_threshold
      end

      it "computes the usage thresholds" do
        thresholds = result.usage_thresholds
        expect(thresholds.size).to eq(2)
        threshold1 = thresholds.first
        threshold2 = thresholds.last

        expect(threshold1[:usage_threshold]).to eq(usage_threshold1)
        expect(threshold1[:amount_cents]).to eq(usage_threshold1.amount_cents)
        expect(threshold1[:completion_ratio]).to eq(1.0)
        expect(threshold1[:reached_at]).to eq(applied_usage_threshold.created_at)

        expect(threshold2[:usage_threshold]).to eq(usage_threshold2)
        expect(threshold2[:amount_cents]).to eq(usage_threshold2.amount_cents)
        expect(threshold2[:completion_ratio]).to eq(0.2)
        expect(threshold2[:reached_at]).to be_nil
      end

      context "when lifetime_usage is above last threshold" do
        let(:applied_usage_threshold2) { create(:applied_usage_threshold, usage_threshold: usage_threshold2, invoice:) }
        let(:current_usage_amount_cents) { 223 }

        before do
          applied_usage_threshold2
        end

        it "computes the usage thresholds" do
          thresholds = result.usage_thresholds
          expect(thresholds.size).to eq(2)
          threshold1 = thresholds.first
          threshold2 = thresholds.last

          expect(threshold1[:usage_threshold]).to eq(usage_threshold1)
          expect(threshold1[:amount_cents]).to eq(usage_threshold1.amount_cents)
          expect(threshold1[:completion_ratio]).to eq(1.0)
          expect(threshold1[:reached_at]).to eq(applied_usage_threshold.created_at)

          expect(threshold2[:usage_threshold]).to eq(usage_threshold2)
          expect(threshold2[:amount_cents]).to eq(usage_threshold2.amount_cents)
          expect(threshold2[:completion_ratio]).to eq(1)
          expect(threshold2[:reached_at]).to eq(applied_usage_threshold2.created_at)
        end
      end

      context "when next threshold is recurring" do
        let(:usage_threshold2) { create_threshold(attached_to:, recurring: true, amount_cents: 200) }

        it "computes the usage thresholds" do
          thresholds = result.usage_thresholds.sort_by { it[:amount_cents] }
          expect(thresholds.size).to eq(2)
          threshold1 = thresholds.first
          threshold2 = thresholds.last

          expect(threshold1[:usage_threshold]).to eq(usage_threshold1)
          expect(threshold1[:amount_cents]).to eq(usage_threshold1.amount_cents)
          expect(threshold1[:completion_ratio]).to eq(1.0)
          expect(threshold1[:reached_at]).to eq(applied_usage_threshold.created_at)

          expect(threshold2[:usage_threshold]).to eq(usage_threshold2)
          expect(threshold2[:amount_cents]).to eq(usage_threshold2.amount_cents + usage_threshold1.amount_cents)
          expect(threshold2[:completion_ratio]).to eq(0.1) # 20/200
          expect(threshold2[:reached_at]).to be_nil
        end

        context "when lifetime_usage is above next threshold" do
          let(:applied_usage_threshold2) { create(:applied_usage_threshold, lifetime_usage_amount_cents: 700, usage_threshold: usage_threshold2, invoice:) }
          let(:current_usage_amount_cents) { 723 }

          before do
            applied_usage_threshold2
          end

          it "computes the usage thresholds" do
            thresholds = result.usage_thresholds
            expect(thresholds.size).to eq(5)
            threshold1 = thresholds.shift

            expect(threshold1[:usage_threshold]).to eq(usage_threshold1)
            expect(threshold1[:amount_cents]).to eq(usage_threshold1.amount_cents)
            expect(threshold1[:completion_ratio]).to eq(1.0)
            expect(threshold1[:reached_at]).to eq(applied_usage_threshold.created_at)

            last_threshold = thresholds.pop

            thresholds.each.with_index do |threshold, index|
              expect(threshold[:usage_threshold]).to eq(usage_threshold2)
              expect(threshold[:amount_cents]).to eq(100 + (index + 1) * 200)
              expect(threshold[:completion_ratio]).to eq(1.0)
              expect(threshold[:reached_at]).to eq(applied_usage_threshold2.created_at)
            end

            expect(last_threshold[:usage_threshold]).to eq(usage_threshold2)
            expect(last_threshold[:amount_cents]).to eq(900)
            expect(last_threshold[:completion_ratio]).to eq(0.115)
            expect(last_threshold[:reached_at]).to be_nil
          end
        end
      end
    end
  end
end
