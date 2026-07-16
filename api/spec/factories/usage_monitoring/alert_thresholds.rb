# frozen_string_literal: true

FactoryBot.define do
  factory :alert_threshold, class: "UsageMonitoring::AlertThreshold" do
    alert
    organization { alert.organization }
    code { "warn" }
    value { rand(40..500) * 100 }
  end
end
