# frozen_string_literal: true

FactoryBot.define do
  factory :triggered_alert, class: "UsageMonitoring::TriggeredAlert" do
    alert
    organization { alert.organization }
    subscription { association(:subscription, organization: alert.organization) }
    current_value { 3000 }
    previous_value { 1000 }
    triggered_at { Time.current }
    crossed_thresholds do
      [
        {code: :warn, value: BigDecimal(2000), recurring: false},
        {code: :repeat, value: BigDecimal(2500), recurring: true}
      ]
    end
  end
end
