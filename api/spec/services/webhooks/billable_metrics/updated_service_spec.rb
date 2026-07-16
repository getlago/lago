# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::BillableMetrics::UpdatedService do
  subject(:webhook_service) { described_class.new(object: billable_metric) }

  let(:organization) { create(:organization) }
  let(:billable_metric) { create(:billable_metric, organization:) }

  describe ".call" do
    it_behaves_like "creates webhook", "billable_metric.updated", "billable_metric", {
      "lago_id" => String,
      "name" => String,
      "code" => String,
      "aggregation_type" => String,
      "recurring" => false,
      "filters" => Array
    }
  end
end
