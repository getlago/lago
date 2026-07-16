# frozen_string_literal: true

require "rails_helper"

RSpec.describe SubscriptionsQuery do
  subject(:result) { described_class.call(organization:, pagination:, filters:, search_term:) }

  let(:returned_ids) { result.subscriptions.pluck(:id) }

  let(:organization) { create(:organization) }
  let(:pagination) { nil }
  let(:filters) { {} }
  let(:search_term) { nil }

  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, customer:, plan:) }

  before { subscription }

  it "returns a list of subscriptions" do
    expect(result).to be_success
    expect(result.subscriptions.count).to eq(1)
    expect(result.subscriptions).to eq([subscription])
  end

  context "when subscriptions have the same values for started_at" do
    let(:subscription) { create(:subscription, customer:, plan:, started_at: 2.days.ago, created_at: 1.day.ago) }
    let(:subscription_2) do
      create(
        :subscription,
        customer:,
        plan:,
        id: "00000000-0000-0000-0000-000000000000",
        started_at: subscription.started_at
      )
    end

    before { subscription_2 }

    it "returns a list sorted by created_at DESC" do
      expect(result).to be_success
      expect(returned_ids).to eq([subscription_2.id, subscription.id])
    end
  end

  context "when subscriptions have the same values for the ordering criteria" do
    let(:subscription) { create(:subscription, customer:, plan:, started_at: 1.day.ago) }
    let(:subscription_2) do
      create(
        :subscription,
        customer:,
        plan:,
        id: "00000000-0000-0000-0000-000000000000",
        started_at: subscription.started_at,
        created_at: subscription.created_at
      )
    end

    before { subscription_2 }

    it "returns a consistent list" do
      expect(result).to be_success
      expect(returned_ids).to eq([subscription_2.id, subscription.id])
    end
  end

  context "with pagination" do
    let(:pagination) { {page: 2, limit: 10} }

    it "applies the pagination" do
      expect(result).to be_success
      expect(result.subscriptions.count).to eq(0)
      expect(result.subscriptions.current_page).to eq(2)
    end
  end

  context "with search_term" do
    let(:subscription) { create(:subscription, customer:, plan:, name: "Test Subscription") }
    let(:subscription_2) { create(:subscription, customer:, plan:, name: "Test Subscription 2") }
    let(:other_plan) { create(:plan, organization:) }
    let(:other_subscription) { create(:subscription, customer:, plan: other_plan, name: "Other Subscription") }

    before { subscription_2 }

    context "when search_term is an id" do
      let(:search_term) { subscription.id }

      it "returns only subscriptions for the specified id" do
        expect(result).to be_success
        expect(result.subscriptions.count).to eq(1)
        expect(result.subscriptions).to eq([subscription])
      end
    end

    context "when search_term is a name" do
      let(:search_term) { subscription_2.name }

      it "returns only subscriptions for the specified name" do
        expect(result).to be_success
        expect(result.subscriptions.count).to eq(1)
        expect(result.subscriptions).to eq([subscription_2])
      end
    end

    context "when search_term is an external_id" do
      let(:search_term) { subscription.external_id }

      it "returns only subscriptions for the specified external_id" do
        expect(result).to be_success
        expect(result.subscriptions.count).to eq(1)
        expect(result.subscriptions).to eq([subscription])
      end
    end

    context "when search_term is a plan name" do
      let(:search_term) { plan.name }

      before { other_subscription }

      it "returns only subscriptions for the specified plan name" do
        expect(result).to be_success
        expect(result.subscriptions.count).to eq(2)
        expect(result.subscriptions).to match_array([subscription, subscription_2])
      end
    end

    context "when search_term is a plan code" do
      let(:search_term) { plan.code }

      before { other_subscription }

      it "returns only subscriptions for the specified plan code" do
        expect(result).to be_success
        expect(result.subscriptions.count).to eq(2)
        expect(result.subscriptions).to match_array([subscription, subscription_2])
      end
    end

    context "when search_term is a customer name" do
      let(:search_term) { customer.name }

      it "returns only subscriptions for the specified customer name" do
        expect(result).to be_success
        expect(result.subscriptions.count).to eq(2)
        expect(result.subscriptions).to match_array([subscription, subscription_2])
      end
    end

    context "when search_term is a customer firstname" do
      let(:search_term) { customer.firstname }

      it "returns only subscriptions for the specified customer firstname" do
        expect(result).to be_success
        expect(result.subscriptions.count).to eq(2)
        expect(result.subscriptions).to match_array([subscription, subscription_2])
      end
    end

    context "when search_term is a customer lastname" do
      let(:search_term) { customer.lastname }

      it "returns only subscriptions for the specified customer lastname" do
        expect(result).to be_success
        expect(result.subscriptions.count).to eq(2)
        expect(result.subscriptions).to match_array([subscription, subscription_2])
      end
    end

    context "when search_term is a customer external_id" do
      let(:search_term) { customer.external_id }

      it "returns only subscriptions for the specified customer external_id" do
        expect(result).to be_success
        expect(result.subscriptions.count).to eq(2)
        expect(result.subscriptions).to match_array([subscription, subscription_2])
      end
    end

    context "when has search_time and plan searchs" do
      let(:search_term) { customer.firstname }
      let(:filters) { {overriden: true} }
      let(:plan2) { create(:plan, organization:, parent: plan) }
      let(:subscription_3) { create(:subscription, customer:, plan: plan2, name: "Test Subscription 3") }

      before { subscription_3 }

      it "returns only subscriptions for the specified customer external_id" do
        expect(result).to be_success
        expect(result.subscriptions.count).to eq(1)
        expect(result.subscriptions).to match_array([subscription_3])
      end
    end
  end

  context "with external_id filter" do
    let(:filters) { {external_id: subscription.external_id} }

    it "applies the filter" do
      expect(result).to be_success
      expect(result.subscriptions).to match_array([subscription])
    end

    context "when search_term is present" do
      let(:search_term) { subscription.external_id }

      before do
        create(:subscription, plan:, name: subscription.external_id)
      end

      it "ignores the search_term" do
        expect(result).to be_success
        expect(result.subscriptions).to match_array([subscription])
      end
    end
  end

  context "with customer filter" do
    let(:filters) { {external_customer_id: customer.external_id} }

    it "applies the filter" do
      expect(result).to be_success
      expect(result.subscriptions.count).to eq(1)
    end
  end

  context "with plan filter" do
    let(:filters) { {plan_code: plan.code} }

    it "applies the filter" do
      expect(result).to be_success
      expect(result.subscriptions.count).to eq(1)
    end
  end

  context "with multiple status filter" do
    let(:filters) { {status: [:active, :pending]} }

    it "returns correct subscriptions" do
      create(:subscription, :pending, customer:, plan:)
      create(:subscription, customer:, plan:, status: :canceled)
      create(:subscription, customer:, plan:, status: :terminated)

      expect(result).to be_success
      expect(result.subscriptions.count).to eq(2)
      expect(result.subscriptions.active.count).to eq(1)
      expect(result.subscriptions.pending.count).to eq(1)
      expect(result.subscriptions.canceled.count).to eq(0)
      expect(result.subscriptions.terminated.count).to eq(0)
    end
  end

  context "with pending status filter" do
    let(:filters) { {status: [:pending]} }

    let(:subscription_1) do
      create(:subscription, :pending, customer:, plan:, created_at: Time.zone.parse("2024-10-12T00:01:01"))
    end

    let(:subscription_2) do
      create(:subscription, :pending, customer:, plan:, created_at: Time.zone.parse("2024-10-10T00:01:01"))
    end

    it "returns only pending subscriptions" do
      subscription_1
      subscription_2
      create(:subscription, customer:, plan:, status: :canceled)
      create(:subscription, customer:, plan:, status: :terminated)

      expect(result).to be_success
      expect(result.subscriptions.count).to eq(2)
      expect(result.subscriptions.active.count).to eq(0)
      expect(result.subscriptions.pending.count).to eq(2)
      expect(result.subscriptions.canceled.count).to eq(0)
      expect(result.subscriptions.terminated.count).to eq(0)
      expect(result.subscriptions.first).to eq(subscription_2) # sorted by subscription_at DESC
    end
  end

  context "with canceled status filter" do
    let(:filters) { {status: [:canceled]} }

    it "returns only pending subscriptions" do
      create(:subscription, :pending, customer:, plan:)
      create(:subscription, customer:, plan:, status: :canceled)
      create(:subscription, customer:, plan:, status: :terminated)

      expect(result).to be_success
      expect(result.subscriptions.count).to eq(1)
      expect(result.subscriptions.active.count).to eq(0)
      expect(result.subscriptions.pending.count).to eq(0)
      expect(result.subscriptions.canceled.count).to eq(1)
      expect(result.subscriptions.terminated.count).to eq(0)
    end
  end

  context "with terminated status filter" do
    let(:filters) { {status: [:terminated]} }

    it "returns only pending subscriptions" do
      create(:subscription, :pending, customer:, plan:)
      create(:subscription, customer:, plan:, status: :canceled)
      create(:subscription, customer:, plan:, status: :terminated)

      expect(result).to be_success
      expect(result.subscriptions.count).to eq(1)
      expect(result.subscriptions.active.count).to eq(0)
      expect(result.subscriptions.pending.count).to eq(0)
      expect(result.subscriptions.canceled.count).to eq(0)
      expect(result.subscriptions.terminated.count).to eq(1)
    end
  end

  context "with no status filter" do
    it "returns all subscriptions" do
      subscription_2 = create(:subscription, customer:, plan:, status: :terminated)
      subscription_3 = create(:subscription, customer:, plan:, status: :canceled)
      subscription_4 = create(:subscription, customer:, plan:, status: :pending)

      expect(result).to be_success
      expect(result.subscriptions.count).to eq(4)
      expect(result.subscriptions.active.count).to eq(1)
      expect(result.subscriptions.pending.count).to eq(1)
      expect(result.subscriptions.canceled.count).to eq(1)
      expect(result.subscriptions.terminated.count).to eq(1)
      expect(result.subscriptions).to match_array([subscription, subscription_2, subscription_3, subscription_4])
    end
  end

  context "with overriden filter" do
    let(:filters) { {} }
    let(:plan) { create(:plan, organization:, parent: parent_plan) }
    let(:parent_plan) { create(:plan, organization:) }
    let(:subscription) { create(:subscription, customer:, plan:) }
    let(:subscription_2) { create(:subscription, customer:, plan: parent_plan) }

    before { [subscription, subscription_2] }

    context "when overriden is true" do
      let(:filters) { {overriden: true} }

      it "returns only overriden subscriptions" do
        expect(result).to be_success
        expect(result.subscriptions.count).to eq(1)
        expect(result.subscriptions).to eq([subscription])
      end
    end

    context "when overriden is false" do
      let(:filters) { {overriden: false} }

      it "returns only non-overriden subscriptions" do
        expect(result).to be_success
        expect(result.subscriptions.count).to eq(1)
        expect(result.subscriptions).to eq([subscription_2])
      end
    end

    context "without overriden filter" do
      it "returns all subscriptions" do
        expect(result).to be_success
        expect(result.subscriptions.count).to eq(2)
        expect(result.subscriptions).to match_array([subscription, subscription_2])
      end
    end
  end

  context "with billing_entity_ids filter" do
    let(:us_entity) { create(:billing_entity, organization:, code: "us") }
    let(:eu_entity) { create(:billing_entity, organization:, code: "eu") }
    let(:subscription) { create(:subscription, customer:, plan:, billing_entity: us_entity) }
    let(:us_subscription) { subscription }
    let(:eu_subscription) { create(:subscription, customer:, plan:, billing_entity: eu_entity) }

    before do
      us_subscription
      eu_subscription
    end

    context "when filtering by a single billing_entity_id" do
      let(:filters) { {billing_entity_ids: [eu_entity.id]} }

      it "returns only subscriptions stamped under that entity" do
        expect(result).to be_success
        expect(result.subscriptions).to eq([eu_subscription])
      end
    end

    context "when filtering by multiple billing_entity_ids" do
      let(:filters) { {billing_entity_ids: [eu_entity.id, us_entity.id]} }

      it "returns subscriptions stamped under any of the given entities" do
        expect(result).to be_success
        expect(result.subscriptions).to match_array([eu_subscription, us_subscription])
      end
    end

    context "when billing_entity_ids is blank" do
      let(:filters) { {billing_entity_ids: []} }

      it "returns all subscriptions" do
        expect(result).to be_success
        expect(result.subscriptions).to match_array([eu_subscription, us_subscription])
      end
    end

    context "when a subscription has NULL billing_entity_id inherits from customer" do
      let(:us_customer) { create(:customer, organization:, billing_entity: us_entity) }
      let(:eu_customer) { create(:customer, organization:, billing_entity: eu_entity) }

      let!(:inherits_eu) { create(:subscription, customer: eu_customer, plan:, billing_entity: nil) }
      let!(:inherits_us) { create(:subscription, customer: us_customer, plan:, billing_entity: nil) }
      let!(:explicit_us_inherit_eu) do
        create(:subscription, customer: eu_customer, plan:, billing_entity: us_entity)
      end
      let!(:explicit_eu_inherit_eu) do
        create(:subscription, customer: eu_customer, plan:, billing_entity: eu_entity)
      end

      context "when filtering for the EU entity" do
        let(:filters) { {billing_entity_ids: [eu_entity.id]} }

        it "returns explicit and inherited matches, excludes mismatched explicit and inherited" do
          expect(result).to be_success
          expect(result.subscriptions).to match_array([
            eu_subscription,
            inherits_eu,
            explicit_eu_inherit_eu
          ])
          expect(returned_ids).not_to include(inherits_us.id)
          expect(returned_ids).not_to include(explicit_us_inherit_eu.id)
        end

        it "does not duplicate subscriptions whose explicit and inherited values both match" do
          expect(returned_ids.count(explicit_eu_inherit_eu.id)).to eq(1)
        end
      end
    end
  end

  context "with currency filter" do
    let(:eur_plan) { create(:plan, organization:, amount_currency: "EUR") }
    let(:usd_plan) { create(:plan, organization:, amount_currency: "USD") }
    let(:eur_subscription) { create(:subscription, customer:, plan: eur_plan) }
    let(:usd_subscription) { create(:subscription, customer:, plan: usd_plan) }
    let(:subscription) { nil }

    before do
      eur_subscription
      usd_subscription
    end

    context "when currency filter is provided" do
      let(:filters) { {currency: "EUR"} }

      it "returns only subscriptions with matching currency" do
        expect(result).to be_success
        expect(result.subscriptions).to eq([eur_subscription])
      end
    end

    context "when currency filter is not provided" do
      let(:filters) { {} }

      it "returns all subscriptions" do
        expect(result).to be_success
        expect(result.subscriptions).to match_array([eur_subscription, usd_subscription])
      end
    end
  end

  context "with exclude_next_subscriptions filter" do
    let(:subscription) { create(:subscription, customer:, plan:, status: :active) }
    let(:next_subscription) { create(:subscription, previous_subscription: subscription, customer:, plan:, status: :pending) }
    let(:pending_subscription) { create(:subscription, :pending, customer:, plan:) }
    let(:terminated_subscription) { create(:subscription, :terminated, customer:, plan:) }

    before do
      subscription
      next_subscription
      pending_subscription
      terminated_subscription
    end

    context "when status filter is empty" do
      let(:filters) { {exclude_next_subscriptions: true, status: []} }

      it "returns only subscriptions without next subscription" do
        expect(result).to be_success
        expect(result.subscriptions.count).to eq(3)
        expect(result.subscriptions).to match_array([subscription, pending_subscription, terminated_subscription])
      end
    end

    context "when status filter is not empty" do
      context "when status filter matches previous subscription status" do
        let(:filters) { {exclude_next_subscriptions: true, status: [:active]} }

        it "returns only subscriptions without previous subscription" do
          expect(result).to be_success
          expect(result.subscriptions.count).to eq(1)
          expect(result.subscriptions).to eq([subscription])
        end
      end

      context "when status filter matches next subscription status" do
        let(:filters) { {exclude_next_subscriptions: true, status: [:pending]} }

        it "returns only subscriptions without next subscription" do
          expect(result).to be_success
          expect(result.subscriptions.count).to eq(2)
          expect(result.subscriptions).to match_array([pending_subscription, next_subscription])
        end
      end

      context "when status filter matches both previous and next subscription status" do
        let(:filters) { {exclude_next_subscriptions: true, status: [:pending, :active]} }

        it "returns only subscriptions without next subscription" do
          expect(result).to be_success
          expect(result.subscriptions.count).to eq(2)
          expect(result.subscriptions).to match_array([subscription, pending_subscription])
        end
      end

      context "when status filter does not match previous or next subscription status" do
        let(:filters) { {exclude_next_subscriptions: true, status: [:terminated]} }

        it "returns only subscriptions without next subscription" do
          expect(result).to be_success
          expect(result.subscriptions.count).to eq(1)
          expect(result.subscriptions).to eq([terminated_subscription])
        end
      end
    end

    context "when status filter contains multiple statuses" do
      let(:filters) { {exclude_next_subscriptions: true, status: [:pending, :active]} }

      let(:pending_without_previous) { create(:subscription, :pending, customer:, plan:) }
      let(:active_without_previous) { create(:subscription, :active, customer:, plan:) }
      let(:pending_with_terminated_previous) { create(:subscription, :pending, :with_previous_subscription, customer:, plan:) }
      let(:active_with_terminated_previous) { create(:subscription, :active, :with_previous_subscription, customer:, plan:) }
      let(:pending_with_pending_previous) { create(:subscription, :pending, :with_previous_subscription, customer:, plan:) }
      let(:subscription) { create(:subscription, :terminated, customer:, plan:) }

      before do
        pending_without_previous
        active_without_previous
        pending_with_terminated_previous.previous_subscription.update!(status: :terminated)
        active_with_terminated_previous.previous_subscription.update!(status: :terminated)
        pending_with_pending_previous.previous_subscription.update!(status: :pending)
      end

      it "returns subscriptions without previous OR with non-matching previous and matching current" do
        expect(result).to be_success
        expect(result.subscriptions.count).to eq(7)
        expect(result.subscriptions).to match_array([
          next_subscription,
          pending_subscription,
          pending_without_previous,
          active_without_previous,
          pending_with_terminated_previous,
          active_with_terminated_previous,
          pending_with_pending_previous.previous_subscription
        ])
      end

      it "excludes subscriptions with matching previous status" do
        expect(result.subscriptions).not_to include(pending_with_pending_previous)
      end
    end

    context "when previous subscription is terminated" do
      let(:subscription) { create(:subscription, customer:, plan:, status: :terminated) }

      it "returns all subscriptions" do
        expect(result).to be_success
        expect(result.subscriptions.count).to eq(4)
        expect(result.subscriptions).to match_array([subscription, next_subscription, pending_subscription, terminated_subscription])
      end

      context "when there is a search term" do
        let(:search_term) { customer.name }

        it "returns all subscriptions" do
          expect(result).to be_success
          expect(result.subscriptions.count).to eq(4)
          expect(result.subscriptions).to match_array([subscription, next_subscription, pending_subscription, terminated_subscription])
        end
      end
    end

    context "when next subscription is canceled" do
      let(:subscription) { create(:subscription, customer:, plan:, status: :active) }
      let(:next_subscription) { create(:subscription, previous_subscription: subscription, customer:, plan:, status: :canceled) }

      it "returns all subscriptions" do
        expect(result).to be_success
        expect(result.subscriptions.count).to eq(4)
        expect(result.subscriptions).to match_array([subscription, next_subscription, pending_subscription, terminated_subscription])
      end
    end
  end
end
