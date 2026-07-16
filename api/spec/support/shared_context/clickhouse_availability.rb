# frozen_string_literal: true

RSpec.shared_context "with clickhouse availability" do
  let(:clickhouse_enabled) { "true" }

  before { ENV["LAGO_CLICKHOUSE_ENABLED"] = clickhouse_enabled }
  after { ENV["LAGO_CLICKHOUSE_ENABLED"] = nil }
end
