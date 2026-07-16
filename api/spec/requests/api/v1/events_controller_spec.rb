# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::EventsController do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:metric) { create(:billable_metric, organization:) }
  let(:plan) { create(:plan, organization:) }
  let!(:subscription) { create(:subscription, customer:, organization:, plan:, started_at: 1.month.ago) }

  describe "POST /api/v1/events" do
    subject do
      post_with_token(organization, "/api/v1/events", event: create_params)
    end

    let(:create_params) do
      {
        code: metric.code,
        transaction_id: SecureRandom.uuid,
        external_subscription_id: subscription.external_id,
        timestamp: Time.current.to_i,
        precise_total_amount_cents: "123.45",
        properties: {
          foo: "bar"
        }
      }
    end

    include_examples "requires API permission", "event", "write"

    it "returns a success" do
      expect { subject }.to change(Event, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(json[:event][:external_subscription_id]).to eq(subscription.external_id)
    end

    it "does not create an audit log", clickhouse: true do
      expect { subject }.not_to change(Clickhouse::ApiLog, :count)
    end

    context "with duplicated transaction_id" do
      let!(:event) { create(:event, organization:, external_subscription_id: subscription.external_id) }

      let(:create_params) do
        {
          code: metric.code,
          transaction_id: event.transaction_id,
          external_subscription_id: subscription.external_id,
          timestamp: Time.current.to_i,
          precise_total_amount_cents: "123.45",
          properties: {
            foo: "bar"
          }
        }
      end

      it "returns a not found response" do
        expect { subject }.not_to change(Event, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when sending wrong format for the timestamp" do
      let(:create_params) do
        {
          code: metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: subscription.external_id,
          timestamp: Time.current.to_s,
          precise_total_amount_cents: "123.45",
          properties: {
            foo: "bar"
          }
        }
      end

      it "returns a not found response" do
        expect { subject }.not_to change(Event, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(json[:error_details]).to eq({timestamp: ["invalid_format"]})
      end
    end

    context "with expression configured on billable metric" do
      let(:metric) { create(:billable_metric, field_name: "value", organization:, expression: "event.properties.a + event.properties.b") }
      let(:create_params) do
        {
          code: metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: subscription.external_id,
          timestamp: Time.current.to_i,
          properties: {
            a: "1",
            b: "2"
          }
        }
      end

      it "evaluates the expression and stores the result" do
        expect { subject }.to change(Event, :count).by(1)

        expect(response).to have_http_status(:success)
        expect(json[:event][:properties]).to include(value: "3.0")
      end

      context "when sending incomplete properties for expression" do
        let(:create_params) do
          {
            code: metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            timestamp: Time.current.to_i,
            properties: {
              a: "1"
            }
          }
        end

        it "fails with a 422 error" do
          expect { subject }.not_to change(Event, :count)
          expect(response).to have_http_status(:unprocessable_content)
          expect(json[:error_details]).to include("Variable: b not found")
        end
      end
    end
  end

  describe "POST /api/v1/events/batch" do
    subject do
      post_with_token(organization, "/api/v1/events/batch", events: batch_params)
    end

    let(:batch_params) do
      [
        {
          code: metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: subscription.external_id,
          timestamp: Time.current.to_i,
          precise_total_amount_cents: "123.45",
          properties: {
            foo: "bar"
          }
        }
      ]
    end

    include_examples "requires API permission", "event", "write"

    it "returns a success" do
      expect { subject }.to change(Event, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(json[:events].first[:external_subscription_id]).to eq(subscription.external_id)
    end

    context "with invalid timestamp for one event" do
      let(:batch_params) do
        [
          {
            code: metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            timestamp: Time.current.to_i,
            precise_total_amount_cents: "123.45",
            properties: {
              foo: "bar"
            }
          },
          {
            code: metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            timestamp: Time.current.to_s,
            precise_total_amount_cents: "123.45",
            properties: {
              foo: "bar"
            }
          }
        ]
      end

      it "returns an error indicating which event contained which error" do
        expect { subject }.not_to change(Event, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(json[:error_details]).to eq({"1": {timestamp: ["invalid_format"]}})
      end
    end

    context "with expression configured on billable metric" do
      let(:metric) { create(:billable_metric, field_name: "value", organization:, expression: "event.properties.a + event.properties.b") }
      let(:batch_params) { [create_params] }
      let(:create_params) do
        {
          code: metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: subscription.external_id,
          timestamp: Time.current.to_i,
          properties: {
            a: "1",
            b: "2"
          }
        }
      end

      it "evaluates the expression and stores the result" do
        expect { subject }.to change(Event, :count).by(1)

        expect(response).to have_http_status(:success)
        expect(json[:events].first[:properties]).to include(value: "3.0")
      end

      context "when sending incomplete properties for expression" do
        let(:create_params) do
          {
            code: metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            timestamp: Time.current.to_i,
            properties: {
              a: "1"
            }
          }
        end

        it "fails with a 422 error" do
          expect { subject }.not_to change(Event, :count)
          expect(response).to have_http_status(:unprocessable_content)
          expect(json[:error_details]).to include("0": "expression_evaluation_failed: Variable: b not found")
        end
      end
    end
  end

  describe "GET /api/v1/events" do
    subject { get_with_token(organization, "/api/v1/events", params) }

    let!(:event) { create(:event, timestamp: 5.days.ago.to_date, organization:) }

    context "without params" do
      let(:params) { {} }

      include_examples "requires API permission", "event", "read"

      it "returns events" do
        subject

        expect(response).to have_http_status(:ok)
        expect(json[:events].count).to eq(1)
        expect(json[:events].first[:lago_id]).to eq(event.id)
      end
    end

    context "with pagination" do
      let(:params) { {page: 1, per_page: 1} }

      before { create(:event, organization:) }

      it "returns events with correct meta data" do
        subject

        expect(response).to have_http_status(:ok)

        expect(json[:events].count).to eq(1)
        expect(json[:meta][:current_page]).to eq(1)
        expect(json[:meta][:next_page]).to eq(2)
        expect(json[:meta][:prev_page]).to eq(nil)
        expect(json[:meta][:total_pages]).to eq(2)
        expect(json[:meta][:total_count]).to eq(2)
      end
    end

    context "with code" do
      let(:params) { {code: event.code} }

      before { create(:event, organization:) }

      it "returns events" do
        subject

        expect(response).to have_http_status(:ok)
        expect(json[:events].count).to eq(1)
        expect(json[:events].first[:lago_id]).to eq(event.id)
      end
    end

    context "with external subscription id" do
      let(:params) { {external_subscription_id: event.external_subscription_id} }

      before { create(:event, organization:) }

      it "returns events" do
        subject

        expect(response).to have_http_status(:ok)
        expect(json[:events].count).to eq(1)
        expect(json[:events].first[:lago_id]).to eq(event.id)
      end
    end

    context "with timestamp" do
      let(:params) do
        {timestamp_from: 2.days.ago.to_date, timestamp_to: Date.tomorrow.to_date}
      end

      let!(:matching_event) { create(:event, timestamp: 1.day.ago.to_date, organization:) }

      before { create(:event, timestamp: 3.days.ago.to_date, organization:) }

      it "returns events with correct timestamp" do
        subject

        expect(response).to have_http_status(:ok)
        expect(json[:events].count).to eq(1)
        expect(json[:events].first[:lago_id]).to eq(matching_event.id)
      end
    end

    context "with timestamp_from_started_at" do
      let(:started_at) { 1.day.ago }
      let(:subscription) { create(:subscription, organization:, started_at:) }
      let(:params) do
        {
          timestamp_from_started_at: true,
          external_subscription_id: subscription.external_id
        }
      end

      it do
        matching_event = create(:event, timestamp: started_at + 1.second, external_subscription_id: subscription.external_id, organization:)
        create(:event, timestamp: started_at - 1.second, external_subscription_id: subscription.external_id, organization:)

        subject

        expect(response).to have_http_status(:ok)
        expect(json[:events].map { it[:lago_id] }).to contain_exactly(matching_event.id)
      end
    end

    context "with timestamp_from_started_at set to false as string" do
      let(:started_at) { 1.day.ago }
      let(:subscription) { create(:subscription, organization:, started_at:) }
      let(:params) do
        {
          timestamp_from: 10.days.ago.to_date,
          timestamp_from_started_at: "false"
        }
      end

      it do
        matching_event = create(:event, timestamp: started_at + 1.second, external_subscription_id: subscription.external_id, organization:)
        other_event = create(:event, timestamp: started_at - 1.second, external_subscription_id: subscription.external_id, organization:)

        subject

        expect(response).to have_http_status(:ok)
        expect(json[:events].map { it[:lago_id] }).to contain_exactly(event.id, other_event.id, matching_event.id)
      end
    end

    context "with clickhouse", clickhouse: true do
      let(:params) { {} }

      before { organization.update!(clickhouse_events_store: true) }

      context "when event is raw" do
        let(:event) do
          Clickhouse::EventsRaw.create!(
            transaction_id: SecureRandom.uuid,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            code: metric.code,
            timestamp: 5.days.ago.to_date,
            properties: {}
          )
        end

        it "returns an event" do
          subject

          expect(response).to have_http_status(:ok)

          json_event = json[:events].sole
          expect(json_event[:lago_subscription_id]).to eq event.subscription_id
          expect(json_event[:lago_customer_id]).to eq event.customer_id
          expect(json_event[:code]).to eq event.code
          expect(json_event[:transaction_id]).to eq event.transaction_id
        end
      end

      context "when event is enriched" do
        let(:event) do
          Clickhouse::EventsEnriched.create!(
            transaction_id: SecureRandom.uuid,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            code: metric.code,
            timestamp: 5.days.ago.to_date,
            properties: {},
            enriched_at: DateTime.new(2025, 1, 1)
          )
        end

        it "does not return any event" do
          subject
          expect(response).to have_http_status(:ok)
          expect(json[:events]).to be_empty
        end
      end
    end
  end

  describe "GET /api/v1/events_enriched" do
    subject { get_with_token(organization, "/api/v1/events_enriched", params) }

    context "without clickhouse" do
      let(:params) { {} }

      it "returns an error" do
        subject
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with clickhouse", clickhouse: true do
      let(:params) { {external_subscription_id: event.external_subscription_id} }

      before { organization.update!(clickhouse_events_store: true) }

      context "when event is raw" do
        let(:event) do
          Clickhouse::EventsRaw.create!(
            transaction_id: SecureRandom.uuid,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            code: metric.code,
            timestamp: 5.days.ago.to_date,
            properties: {}
          )
        end

        it "does not return any event" do
          subject

          expect(response).to have_http_status(:ok)
          expect(response.headers["X-Lago-Endpoint-Status"]).to eq("beta")
          expect(json[:events]).to be_empty
        end
      end

      context "when event is enriched" do
        let(:event) do
          Clickhouse::EventsEnriched.create!(
            transaction_id: SecureRandom.uuid,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            code: metric.code,
            timestamp: 5.days.ago.to_date,
            properties: {},
            enriched_at: DateTime.new(2025, 1, 1)
          )
        end

        it "returns an event" do
          subject

          expect(response).to have_http_status(:ok)
          expect(response.headers["X-Lago-Endpoint-Status"]).to eq("beta")

          json_event = json[:events].sole
          expect(json_event[:enriched_at]).to eq "2025-01-01T00:00:00.000Z"
          expect(json_event[:code]).to eq event.code
          expect(json_event[:transaction_id]).to eq event.transaction_id
          expect(json_event).not_to have_key(:lago_subscription_id)
          expect(json_event).not_to have_key(:lago_customer_id)
        end
      end
    end
  end

  describe "GET /api/v1/events/:id" do
    subject { get_with_token(organization, "/api/v1/events/#{CGI.escapeURIComponent(transaction_id)}") }

    let(:event) { create(:event, organization_id: organization.id, transaction_id: event_transaction_id) }
    let(:event_transaction_id) { SecureRandom.uuid }
    let(:transaction_id) { event_transaction_id }

    before { event }

    include_examples "requires API permission", "event", "read"

    it "returns an event" do
      subject

      expect(response).to have_http_status(:ok)

      %i[code transaction_id].each do |property|
        expect(json[:event][property]).to eq event.attributes[property.to_s]
      end

      expect(json[:event][:lago_subscription_id]).to eq event.subscription_id
      expect(json[:event][:lago_customer_id]).to eq event.customer_id
    end

    context "when transaction_id contains special characters" do
      let(:event_transaction_id) { "1Az()[]?#._/|-/../" }

      it "returns an event" do
        subject

        expect(response).to have_http_status(:ok)
        expect(json[:event][:transaction_id]).to eq event.transaction_id
      end
    end

    context "with a non-existing transaction_id" do
      let(:transaction_id) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when event is deleted" do
      before { event.discard! }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with clickhouse", clickhouse: true do
      let(:event) do
        Clickhouse::EventsRaw.create!(
          transaction_id: event_transaction_id,
          organization_id: organization.id,
          external_subscription_id: subscription.external_id,
          code: metric.code,
          timestamp: 5.days.ago.to_date,
          properties: {}
        )
      end

      before { organization.update!(clickhouse_events_store: true) }

      it "returns an event" do
        subject

        expect(response).to have_http_status(:ok)

        %i[code transaction_id].each do |property|
          expect(json[:event][property]).to eq event.attributes[property.to_s]
        end

        expect(json[:event][:lago_subscription_id]).to eq event.subscription_id
        expect(json[:event][:lago_customer_id]).to eq event.customer_id
      end
    end
  end

  describe "POST /api/v1/events/estimate_fees" do
    subject do
      post_with_token(organization, "/api/v1/events/estimate_fees", event: event_params)
    end

    let(:charge) { create(:standard_charge, :pay_in_advance, plan:, billable_metric: metric) }
    let(:tax) { create(:tax, organization:) }

    let(:event_params) do
      {
        code: metric.code,
        external_subscription_id: subscription.external_id,
        transaction_id: SecureRandom.uuid,
        precise_total_amount_cents: "123.45",
        properties: {
          foo: "bar"
        }
      }
    end

    before do
      charge
      tax
    end

    include_examples "requires API permission", "event", "write"

    it "returns a success" do
      subject

      expect(response).to have_http_status(:success)

      expect(json[:fees].count).to eq(1)

      fee = json[:fees].first
      expect(fee[:lago_id]).to be_nil
      expect(fee[:lago_group_id]).to be_nil
      expect(fee[:item][:type]).to eq("charge")
      expect(fee[:item][:code]).to eq(metric.code)
      expect(fee[:item][:name]).to eq(metric.name)
      expect(fee[:pay_in_advance]).to eq(true)
      expect(fee[:amount_cents]).to be_an(Integer)
      expect(fee[:amount_currency]).to eq("EUR")
      expect(fee[:units]).to eq("1.0")
      expect(fee[:events_count]).to eq(1)
    end

    context "with taxes applied to the billing entity" do
      let(:tax) { create(:tax, :applied_to_billing_entity, organization:, billing_entity: customer.billing_entity, rate: 20.0) }

      it "returns fees with tax information" do
        subject

        expect(response).to have_http_status(:success)

        fee = json[:fees].first
        expect(fee[:taxes_amount_cents]).to be_positive
        expect(fee[:taxes_rate]).to eq(20.0)
        expect(fee[:applied_taxes].count).to eq(1)
        expect(fee[:applied_taxes].first[:tax_rate]).to eq(20.0)
      end
    end

    context "with missing customer id" do
      let(:event_params) do
        {
          code: metric.code,
          external_subscription_id: nil,
          properties: {
            foo: "bar"
          }
        }
      end

      it "returns a not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when metric code does not match an pay_in_advance charge" do
      let(:charge) { create(:standard_charge, plan:, billable_metric: metric) }

      let(:event_params) do
        {
          code: metric.code,
          external_subscription_id: subscription.external_id,
          properties: {
            foo: "bar"
          }
        }
      end

      it "returns a validation error" do
        subject
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "POST /api/v1/events/batch_estimate_instant_fees" do
    subject do
      post_with_token(organization, "/api/v1/events/batch_estimate_instant_fees", events: batch_params)
    end

    let(:metric) { create(:sum_billable_metric, organization:) }
    let(:charge) { create(:percentage_charge, :pay_in_advance, plan:, billable_metric: metric, properties: {rate: "0.1", fixed_amount: "0"}) }

    let(:event_params) do
      {
        code: metric.code,
        organization_id: organization.id,
        external_subscription_id: subscription.external_id,
        transaction_id: SecureRandom.uuid,
        properties: {
          metric.field_name => 400
        }
      }
    end

    let(:batch_params) { [event_params] }

    before do
      charge
    end

    include_examples "requires API permission", "event", "write"

    it "returns a success" do
      subject

      expect(response).to have_http_status(:success)

      expect(json[:fees].count).to eq(1)

      fee = json[:fees].first
      expect(fee[:lago_id]).to be_nil
      expect(fee[:lago_group_id]).to be_nil
      expect(fee[:item][:type]).to eq("charge")
      expect(fee[:item][:code]).to eq(metric.code)
      expect(fee[:item][:name]).to eq(metric.name)
      expect(fee[:amount_cents]).to eq("40.0")
      expect(fee[:amount_currency]).to eq("EUR")
      expect(fee[:units]).to eq("400.0")
      expect(fee[:events_count]).to eq(1)
    end

    context "with multiple events" do
      let(:event2_params) do
        {
          code: metric.code,
          organization_id: organization.id,
          external_subscription_id: subscription.external_id,
          transaction_id: SecureRandom.uuid,
          properties: {
            metric.field_name => 300
          }
        }
      end

      let(:batch_params) { [event_params, event2_params] }

      it "returns a success" do
        subject

        expect(response).to have_http_status(:success)

        expect(json[:fees].count).to eq(2)
        fee1 = json[:fees].find { |f| f[:event_transaction_id] == event_params[:transaction_id] }
        fee2 = json[:fees].find { |f| f[:event_transaction_id] == event2_params[:transaction_id] }

        expect(fee1[:lago_id]).to be_nil
        expect(fee1[:lago_group_id]).to be_nil
        expect(fee1[:item][:type]).to eq("charge")
        expect(fee1[:item][:code]).to eq(metric.code)
        expect(fee1[:item][:name]).to eq(metric.name)
        expect(fee1[:amount_cents]).to eq("40.0")
        expect(fee1[:amount_currency]).to eq("EUR")
        expect(fee1[:units]).to eq("400.0")
        expect(fee1[:events_count]).to eq(1)
        expect(fee2[:lago_id]).to be_nil
        expect(fee2[:lago_group_id]).to be_nil
        expect(fee2[:item][:type]).to eq("charge")
        expect(fee2[:item][:code]).to eq(metric.code)
        expect(fee2[:item][:name]).to eq(metric.name)
        expect(fee2[:amount_cents]).to eq("30.0")
        expect(fee2[:amount_currency]).to eq("EUR")
        expect(fee2[:units]).to eq("300.0")
        expect(fee2[:events_count]).to eq(1)
      end
    end
  end

  describe "POST /api/v1/events/estimate_instant_fees" do
    subject do
      post_with_token(organization, "/api/v1/events/estimate_instant_fees", event: event_params)
    end

    let(:metric) { create(:sum_billable_metric, organization:) }
    let(:charge) { create(:percentage_charge, :pay_in_advance, plan:, billable_metric: metric, properties: {rate: "0.1", fixed_amount: "0"}) }

    let(:event_params) do
      {
        code: metric.code,
        organization_id: organization.id,
        external_subscription_id: subscription.external_id,
        transaction_id: SecureRandom.uuid,
        properties: {
          metric.field_name => 400
        }
      }
    end

    before do
      charge
    end

    include_examples "requires API permission", "event", "write"

    it "returns a success" do
      subject

      expect(response).to have_http_status(:success)

      expect(json[:fees].count).to eq(1)

      fee = json[:fees].first
      expect(fee[:lago_id]).to be_nil
      expect(fee[:lago_group_id]).to be_nil
      expect(fee[:item][:type]).to eq("charge")
      expect(fee[:item][:code]).to eq(metric.code)
      expect(fee[:item][:name]).to eq(metric.name)
      expect(fee[:amount_cents]).to eq("40.0")
      expect(fee[:amount_currency]).to eq("EUR")
      expect(fee[:units]).to eq("400.0")
      expect(fee[:events_count]).to eq(1)
    end

    context "with missing subscription id" do
      let(:event_params) do
        {
          code: metric.code,
          external_subscription_id: nil,
          properties: {
            foo: "bar"
          }
        }
      end

      it "returns a not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when metric code does not match an percentage charge" do
      let(:charge) { create(:standard_charge, plan:, billable_metric: metric) }

      let(:event_params) do
        {
          code: metric.code,
          external_subscription_id: subscription.external_id,
          properties: {
            foo: "bar"
          }
        }
      end

      it "returns a validation error" do
        subject
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
