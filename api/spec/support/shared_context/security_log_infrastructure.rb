# frozen_string_literal: true

RSpec.shared_context "with security log infrastructure" do
  let(:clickhouse_enabled) { "true" }
  let(:kafka_bootstrap_servers) { "kafka" }
  let(:kafka_security_logs_topic) { "security_logs" }

  before do
    ENV["LAGO_CLICKHOUSE_ENABLED"] = clickhouse_enabled
    ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"] = kafka_bootstrap_servers
    ENV["LAGO_KAFKA_SECURITY_LOGS_TOPIC"] = kafka_security_logs_topic
  end

  after do
    ENV["LAGO_CLICKHOUSE_ENABLED"] = nil
    ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"] = nil
    ENV["LAGO_KAFKA_SECURITY_LOGS_TOPIC"] = nil
  end
end
