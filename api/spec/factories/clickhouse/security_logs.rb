# frozen_string_literal: true

FactoryBot.define do
  factory :clickhouse_security_log, class: "Clickhouse::SecurityLog" do
    transient do
      membership { create(:membership) }
    end

    organization { membership.organization }
    user_id { membership.user_id }
    api_key_id { create(:api_key, organization: membership.organization).id }
    log_type { "user" }
    log_event { "user.signed_up" }
    logged_at { Time.current }
    device_info { {"browser" => "Chrome", "os" => "macOS"} }
    resources { {"user_email" => "test@example.com"} }
  end
end
