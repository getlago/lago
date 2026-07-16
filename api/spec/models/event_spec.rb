# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event do
  subject { build(:event) }

  it { is_expected.to have_many(:enriched_events) }

  it { is_expected.to validate_presence_of(:transaction_id) }
  it { is_expected.to validate_presence_of(:code) }

  describe "#customer" do
    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:) }
    let(:subscription) { create(:subscription, organization:, customer:) }
    let(:external_customer_id) { customer.external_id }
    let(:external_subscription_id) { subscription.external_id }

    let(:timestamp) { Time.current - 1.second }

    let(:event) do
      create(
        :event,
        organization:,
        external_customer_id:,
        external_subscription_id:,
        timestamp:
      )
    end

    it "returns the customer" do
      expect(event.customer).to eq(customer)
    end

    context "when a customer with the same external id was deleted" do
      let(:deleted_at) { timestamp - 2.days }
      let(:deleted_customer) do
        create(:customer, organization:, external_id: external_customer_id, deleted_at:)
      end

      before { deleted_customer }

      it "returns the customer" do
        expect(event.customer).to eq(customer)
      end

      context "when the timestamp is before the deleted date" do
        let(:deleted_at) { timestamp + 2.days }

        it "returns the deleted customer" do
          expect(event.customer).to eq(deleted_customer)
        end
      end
    end
  end

  describe "#subscription" do
    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:) }
    let(:plan) { create(:plan, organization:) }
    let(:subscription) { create(:subscription, organization:, customer:, plan:, started_at:) }

    let(:started_at) { Time.current - 3.days }
    let(:external_customer_id) { customer.external_id }
    let(:external_subscription_id) { subscription.external_id }
    let(:timestamp) { Time.current - 1.second }

    let(:event) do
      create(
        :event,
        organization:,
        external_customer_id:,
        external_subscription_id:,
        timestamp:
      )
    end

    it "returns the subscription" do
      expect(event.subscription).to eq(subscription)
    end

    context "without external_customer_id" do
      let(:external_customer_id) { nil }

      it "returns the subscription" do
        expect(event.subscription).to eq(subscription)
      end
    end

    context "when subscription is terminated" do
      let(:subscription) { create(:subscription, :terminated, organization:, customer:, started_at:) }

      it "returns the subscription" do
        expect(event.subscription).to eq(subscription)
      end

      context "when subscription is terminated just after the ingestion" do
        before do
          subscription.update!(terminated_at: timestamp + 0.2.seconds)
        end

        it "returns the subscription" do
          expect(event.subscription).to eq(subscription)
        end
      end

      context "when a new active subscription exists" do
        let(:started_at) { 1.month.ago }
        let(:timestamp) { 1.week.ago }

        let(:active_subscription) do
          create(
            :subscription,
            customer:,
            organization:,
            started_at: 1.day.ago,
            external_id: subscription.external_id
          )
        end

        before { active_subscription }

        it "returns the active subscription" do
          expect(event.subscription).to eq(subscription)
        end
      end

      context "when subscription is an upgrade/downgrade" do
        let(:started_at) { 1.week.ago }

        let(:terminated_subscription) do
          create(
            :subscription,
            :terminated,
            organization:,
            customer:,
            external_id: external_subscription_id,
            started_at: 1.month.ago,
            terminated_at: timestamp - 1.day
          )
        end

        before { terminated_subscription }

        it "returns the subscription" do
          expect(event.subscription).to eq(subscription)
        end
      end
    end
  end
end
