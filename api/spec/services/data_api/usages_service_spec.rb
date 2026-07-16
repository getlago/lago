# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataApi::UsagesService do
  let(:service) { described_class.new(organization, **params) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:body_response) { File.read("spec/fixtures/lago_data_api/usages.json") }
  let(:from_date) { Date.current - 60.days }

  let(:usage_json) do
    {
      "start_of_period_dt" => "2024-01-01",
      "end_of_period_dt" => "2024-01-31",
      "billable_metric_code" => "account_members",
      "is_billable_metric_deleted" => false,
      "amount_currency" => "EUR",
      "amount_cents" => 26600,
      "units" => 266
    }
  end

  describe "#call" do
    subject(:service_call) { service.call }

    let(:params) { {} }

    context "when licence is not premium" do
      let(:query) { {time_granularity: "daily", start_of_period_dt: Date.current - 30.days} }

      before do
        stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/usages/#{organization.id}/")
          .with(query:)
          .to_return(status: 200, body: body_response, headers: {})
      end

      context "when billable metric is not deleted" do
        it "returns usages" do
          expect(service_call).to be_success
          expect(service_call.usages.count).to eq(3)
          expect(service_call.usages.first).to eq(usage_json)
        end
      end

      context "when billable metric is deleted" do
        before do
          create(:billable_metric, :discarded, organization:, code: "account_members")
          usage_json["is_billable_metric_deleted"] = true
        end

        it "returns usages" do
          expect(service_call).to be_success
          expect(service_call.usages.count).to eq(3)
          expect(service_call.usages.first).to eq(usage_json)
        end
      end
    end

    context "when licence is premium", :premium do
      let(:query) { {time_granularity: "daily"} }

      before do
        stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/usages/#{organization.id}/")
          .with(query:)
          .to_return(status: 200, body: body_response, headers: {})
      end

      context "when billable metric is not deleted" do
        it "returns usages" do
          expect(service_call).to be_success
          expect(service_call.usages.count).to eq(3)
          expect(service_call.usages.first).to eq(usage_json)
        end
      end

      context "when billable metric is deleted" do
        before do
          create(:billable_metric, :discarded, organization:, code: "account_members")
          usage_json["is_billable_metric_deleted"] = true
        end

        it "returns usages" do
          expect(service_call).to be_success
          expect(service_call.usages.count).to eq(3)
          expect(service_call.usages.first).to eq(usage_json)
        end
      end
    end

    context "when the data api returns a transient error before succeeding" do
      let(:query) { {time_granularity: "daily", start_of_period_dt: Date.current - 30.days} }

      before do
        call_count = 0
        stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/usages/#{organization.id}/")
          .with(query:)
          .to_return do
            call_count += 1
            if call_count == 1
              {status: 500, body: "transient error", headers: {}}
            else
              {status: 200, body: body_response, headers: {}}
            end
          end
      end

      it "retries and returns usages" do
        expect(service_call).to be_success
        expect(service_call.usages.count).to eq(3)
      end
    end
  end

  describe "#filtered_params" do
    subject(:filtered_params) { service.send(:filtered_params) }

    context "when licence is not premium" do
      context "when additional params are provided" do
        let(:params) do
          {
            billable_metric_code: "code",
            time_granularity: "weekly",
            from_date: Date.current - 60.days,
            additional_param: "value"
          }
        end

        it "returns default params with daily granularity and 30 days back start date" do
          expect(filtered_params).to eq(
            time_granularity: "daily",
            start_of_period_dt: Date.current - 30.days,
            billable_metric_code: "code"
          )
        end
      end

      context "when no params are provided" do
        let(:params) { {} }

        it "returns default params with daily granularity and 30 days back start date" do
          expect(filtered_params).to eq(
            time_granularity: "daily",
            start_of_period_dt: Date.current - 30.days
          )
        end
      end

      context "when time_granularity is not provided" do
        let(:params) { {start_of_period_dt: Date.current - 30.days} }

        it "adds default daily time granularity to params" do
          expect(filtered_params).to eq(
            time_granularity: "daily",
            start_of_period_dt: Date.current - 30.days
          )
        end
      end
    end

    context "when licence is premium", :premium do
      let(:params) { {time_granularity: "monthly"} }

      it "returns params with time granularity preserved" do
        expect(filtered_params).to eq(params)
      end

      context "when additional params are provided" do
        let(:params) { {time_granularity: "monthly", additional_param: "value", from_date:} }

        it "includes the additional params in the filtered params" do
          expect(filtered_params).to eq(
            time_granularity: "monthly",
            from_date:,
            additional_param: "value"
          )
        end
      end

      context "when time_granularity is not provided" do
        let(:params) { {} }

        it "adds default daily time granularity to params" do
          expect(filtered_params).to eq(time_granularity: "daily")
        end
      end
    end
  end

  describe "#action_path" do
    subject(:action_path) { service.send(:action_path) }

    let(:params) { {} }

    it "returns the correct API path for the organization" do
      expect(action_path).to eq("usages/#{organization.id}/")
    end
  end

  describe "#discarded_billable_metrics_codes" do
    subject(:discarded_codes) { service.send(:discarded_billable_metrics_codes) }

    let(:params) { {} }

    context "when there are discarded billable metrics" do
      before do
        create(:billable_metric, organization: organization, code: "active_metric")
        create(:billable_metric, :discarded, organization: organization, code: "deleted_metric")
      end

      it "returns the codes of discarded billable metrics" do
        expect(discarded_codes).to match_array(["deleted_metric"])
      end
    end

    context "when there are no discarded billable metrics" do
      before do
        create(:billable_metric, organization: organization, code: "active_metric")
      end

      it "returns an empty array" do
        expect(discarded_codes).to be_empty
      end
    end

    context "when there are discarded metrics from other organizations" do
      let(:other_organization) { create(:organization) }

      before do
        create(:billable_metric, organization: organization, code: "active_metric")
        create(:billable_metric, :discarded, organization: organization, code: "deleted_metric")
        create(:billable_metric, :discarded, organization: other_organization, code: "other_org_deleted")
      end

      it "only returns the codes of discarded billable metrics for the current organization" do
        expect(discarded_codes).to contain_exactly("deleted_metric")
      end
    end
  end
end
