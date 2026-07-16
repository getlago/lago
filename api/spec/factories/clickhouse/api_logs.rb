# frozen_string_literal: true

FactoryBot.define do
  factory :clickhouse_api_log, class: "Clickhouse::ApiLog" do
    transient do
      membership { create(:membership) }
    end

    api_version { "v1" }
    client { "RSpec" }
    logged_at { Time.current }
    request_body { {"foo" => "bar", "baz" => "qux"} }
    http_method { "post" }
    http_status { 200 }
    request_origin { "https://lago.test" }
    request_path { "/api/v1/test-endpoint" }
    request_response { {"foo" => "bar"} }
    api_key_id { create(:api_key, organization: membership.organization).id }
    organization { membership.organization }
  end
end
