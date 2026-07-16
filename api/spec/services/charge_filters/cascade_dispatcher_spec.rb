# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeFilters::CascadeDispatcher do
  let(:organization) { create(:organization) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:charge) { create(:standard_charge, plan:, billable_metric:) }

  let(:us_values) { {"region" => ["us"]} }
  let(:eu_values) { {"region" => ["eu"]} }

  describe ".call" do
    context "when a filter is added" do
      let(:before) { [] }
      let(:after) do
        [{values: us_values, properties: {"amount" => "10"}, invoice_display_name: "US"}]
      end

      it "enqueues a create cascade job" do
        expect {
          described_class.call(charge:, before:, after:)
        }.to have_enqueued_job(ChargeFilters::CascadeJob).with(
          charge.id, "create", us_values, nil, {"amount" => "10"}, "US"
        )
      end
    end

    context "when a filter is removed" do
      let(:before) do
        [{values: us_values, properties: {"amount" => "10"}, invoice_display_name: "US"}]
      end
      let(:after) { [] }

      it "enqueues a destroy cascade job" do
        expect {
          described_class.call(charge:, before:, after:)
        }.to have_enqueued_job(ChargeFilters::CascadeJob).with(
          charge.id, "destroy", us_values, {"amount" => "10"}, nil, "US"
        )
      end
    end

    context "when a filter's properties change" do
      let(:before) do
        [{values: us_values, properties: {"amount" => "10"}, invoice_display_name: "US"}]
      end
      let(:after) do
        [{values: us_values, properties: {"amount" => "15"}, invoice_display_name: "US"}]
      end

      it "enqueues an update cascade job carrying both old and new properties" do
        expect {
          described_class.call(charge:, before:, after:)
        }.to have_enqueued_job(ChargeFilters::CascadeJob).with(
          charge.id, "update", us_values, {"amount" => "10"}, {"amount" => "15"}, "US"
        )
      end
    end

    context "when a filter's invoice_display_name changes" do
      let(:before) do
        [{values: us_values, properties: {"amount" => "10"}, invoice_display_name: "US"}]
      end
      let(:after) do
        [{values: us_values, properties: {"amount" => "10"}, invoice_display_name: "US region"}]
      end

      it "enqueues an update cascade job with the new display name" do
        expect {
          described_class.call(charge:, before:, after:)
        }.to have_enqueued_job(ChargeFilters::CascadeJob).with(
          charge.id, "update", us_values, {"amount" => "10"}, {"amount" => "10"}, "US region"
        )
      end
    end

    context "when a filter is unchanged" do
      let(:filter) { {values: us_values, properties: {"amount" => "10"}, invoice_display_name: "US"} }
      let(:before) { [filter] }
      let(:after) { [filter] }

      it "does not enqueue any cascade job" do
        expect {
          described_class.call(charge:, before:, after:)
        }.not_to have_enqueued_job(ChargeFilters::CascadeJob)
      end
    end

    context "with a mix of create, update, destroy and unchanged" do
      let(:asia_values) { {"region" => ["asia"]} }
      let(:ca_values) { {"region" => ["ca"]} }

      let(:before) do
        [
          {values: us_values, properties: {"amount" => "10"}, invoice_display_name: "US"},
          {values: eu_values, properties: {"amount" => "20"}, invoice_display_name: "EU"},
          {values: asia_values, properties: {"amount" => "30"}, invoice_display_name: "Asia"}
        ]
      end

      let(:after) do
        [
          {values: us_values, properties: {"amount" => "10"}, invoice_display_name: "US"},   # unchanged
          {values: eu_values, properties: {"amount" => "25"}, invoice_display_name: "EU"},   # update
          {values: ca_values, properties: {"amount" => "40"}, invoice_display_name: "CA"}    # create
          # asia removed → destroy
        ]
      end

      it "enqueues exactly one job per change and skips the unchanged filter" do
        expect {
          described_class.call(charge:, before:, after:)
        }.to have_enqueued_job(ChargeFilters::CascadeJob).exactly(3).times
      end

      it "enqueues the update job for the modified filter" do
        expect {
          described_class.call(charge:, before:, after:)
        }.to have_enqueued_job(ChargeFilters::CascadeJob).with(
          charge.id, "update", eu_values, {"amount" => "20"}, {"amount" => "25"}, "EU"
        )
      end

      it "enqueues the create job for the new filter" do
        expect {
          described_class.call(charge:, before:, after:)
        }.to have_enqueued_job(ChargeFilters::CascadeJob).with(
          charge.id, "create", ca_values, nil, {"amount" => "40"}, "CA"
        )
      end

      it "enqueues the destroy job for the removed filter" do
        expect {
          described_class.call(charge:, before:, after:)
        }.to have_enqueued_job(ChargeFilters::CascadeJob).with(
          charge.id, "destroy", asia_values, {"amount" => "30"}, nil, "Asia"
        )
      end
    end
  end
end
