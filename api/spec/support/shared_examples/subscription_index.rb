# frozen_string_literal: true

RSpec.shared_examples "a subscription index endpoint" do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:, amount_cents: 500, description: "desc") }
  let!(:subscription) { create(:subscription, customer:, plan:) }
  let(:external_customer_id) { customer.external_id }
  let(:params) { {} }

  include_examples "requires API permission", "subscription", "read"

  it "returns subscriptions" do
    subject

    expect(response).to have_http_status(:success)
    expect(json[:subscriptions].count).to eq(1)
    expect(json[:subscriptions].first[:lago_id]).to eq(subscription.id)
  end

  context "with next and previous subscriptions" do
    let(:previous_subscription) do
      create(
        :subscription,
        customer:,
        plan: create(:plan, organization:),
        status: :terminated
      )
    end

    let(:next_subscription) do
      create(
        :subscription,
        customer:,
        plan: create(:plan, organization:),
        status: :pending
      )
    end

    before do
      subscription.update!(previous_subscription:, next_subscriptions: [next_subscription])
    end

    it "returns next and previous plan code" do
      subject

      subscription = json[:subscriptions].first
      expect(subscription[:previous_plan_code]).to eq(previous_subscription.plan.code)
      expect(subscription[:next_plan_code]).to eq(next_subscription.plan.code)
    end

    it "returns the downgrade plan date" do
      current_date = DateTime.parse("20 Jun 2022")

      travel_to(current_date) do
        subject

        subscription = json[:subscriptions].first
        expect(subscription[:downgrade_plan_date]).to eq("2022-07-01")
      end
    end
  end

  context "with pagination" do
    let(:params) do
      {
        page: 1,
        per_page: 1
      }
    end

    before do
      another_plan = create(:plan, organization:, amount_cents: 30_000)
      create(:subscription, customer:, plan: another_plan)
    end

    it "returns subscriptions with correct meta data" do
      subject

      expect(response).to have_http_status(:success)

      expect(json[:subscriptions].count).to eq(1)
      expect(json[:meta][:current_page]).to eq(1)
      expect(json[:meta][:next_page]).to eq(2)
      expect(json[:meta][:prev_page]).to eq(nil)
      expect(json[:meta][:total_pages]).to eq(2)
      expect(json[:meta][:total_count]).to eq(2)
    end
  end

  context "with plan code" do
    let(:params) { {plan_code: plan.code} }

    it "returns subscriptions" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:subscriptions].count).to eq(1)
      expect(json[:subscriptions].first[:lago_id]).to eq(subscription.id)
    end
  end

  context "with overriden filter" do
    let(:overridden_plan) { create(:plan, organization:, parent_id: plan.id) }
    let!(:overridden_subscription) { create(:subscription, customer:, plan: overridden_plan) }

    context "when filtering overridden subscriptions" do
      let(:params) { {overriden: true} }

      it "returns only overridden subscriptions" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscriptions].count).to eq(1)
        expect(json[:subscriptions].first[:lago_id]).to eq(overridden_subscription.id)
      end
    end

    context "when filtering non-overridden subscriptions" do
      let(:params) { {overriden: false} }

      it "returns only non-overridden subscriptions" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscriptions].count).to eq(1)
        expect(json[:subscriptions].first[:lago_id]).to eq(subscription.id)
      end
    end

    context "when using overridden (correct spelling)" do
      let(:params) { {overridden: true} }

      it "returns only overridden subscriptions" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscriptions].count).to eq(1)
        expect(json[:subscriptions].first[:lago_id]).to eq(overridden_subscription.id)
      end
    end
  end

  context "with currency filter" do
    let(:brl_plan) { create(:plan, organization:, amount_currency: "BRL") }
    let!(:brl_subscription) { create(:subscription, customer:, plan: brl_plan) }
    let(:params) { {currency: brl_plan.amount_currency} }

    it "returns only subscriptions with matching currency" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:subscriptions].count).to eq(1)
      expect(json[:subscriptions].first[:lago_id]).to eq(brl_subscription.id)
    end
  end

  context "with external_id filter" do
    let(:params) { {external_id: subscription_external_id, status: %i[active terminated]} }
    let(:subscription_external_id) { SecureRandom.uuid }

    let!(:subscriptions) do
      [
        create(:subscription, :active, customer:, external_id: subscription_external_id),
        create(:subscription, :terminated, customer:, external_id: subscription_external_id)
      ]
    end

    it "returns subscriptions matching external_id" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:subscriptions].count).to eq(2)
      expect(json[:subscriptions].pluck(:lago_id)).to match_array(subscriptions.map(&:id))
    end
  end

  context "with billing_entity_codes filter" do
    let(:us_entity) { create(:billing_entity, organization:, code: "us") }
    let(:eu_entity) { create(:billing_entity, organization:, code: "eu") }
    let!(:eu_subscription) { create(:subscription, customer:, plan:, billing_entity: eu_entity) }
    let!(:us_subscription) { create(:subscription, customer:, plan:, billing_entity: us_entity) }

    context "when filtering by a single code" do
      let(:params) { {billing_entity_codes: [eu_entity.code]} }

      it "returns only subscriptions stamped under that entity" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscriptions].pluck(:lago_id)).to eq([eu_subscription.id])
      end
    end

    context "when filtering by multiple codes" do
      let(:params) { {billing_entity_codes: [eu_entity.code, us_entity.code]} }

      it "returns subscriptions stamped under any of the given entities" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscriptions].pluck(:lago_id)).to match_array([eu_subscription.id, us_subscription.id])
      end
    end

    context "when a code does not exist" do
      let(:params) { {billing_entity_codes: ["unknown"]} }

      it "returns a not found error" do
        subject

        expect(response).to be_not_found_error("billing_entity")
      end
    end
  end

  context "with N+1 query detection", bullet: {n_plus_one_query: true, unused_eager_loading: false} do
    before do
      create(:subscription, customer:, plan: create(:plan, organization:))

      prev = create(:subscription, customer:, plan: create(:plan, organization:), status: :terminated)
      nxt = create(:subscription, customer:, plan: create(:plan, organization:), status: :pending)
      subscription.update!(previous_subscription: prev, next_subscriptions: [nxt])
    end

    it "does not trigger N+1 queries on plan, customer, or related subscriptions" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:subscriptions].count).to be >= 2
    end
  end

  context "with terminated status" do
    let!(:terminated_subscription) do
      create(:subscription, customer:, plan: create(:plan, organization:), status: :terminated, terminated_at: Time.current)
    end

    let(:params) do
      {
        status: ["terminated"]
      }
    end

    it "returns terminated subscriptions" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:subscriptions].count).to eq(1)
      expect(json[:subscriptions].first[:lago_id]).to eq(terminated_subscription.id)
    end
  end
end
