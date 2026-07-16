# frozen_string_literal: true

FactoryBot.define do
  factory :order_form do
    customer
    organization { customer&.organization || association(:organization) }
    quote_version do
      association(:quote_version,
        organization:,
        quote: association(:quote, organization:, customer:))
    end
    status { :generated }

    trait :signed do
      status { :signed }
      signed_at { Time.current }
    end

    trait :with_signed_document do
      signed_document { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/blank.pdf"), "application/pdf") }
    end

    trait :expired do
      status { :expired }
      expires_at { 1.day.ago }
      voided_at { Time.current }
      void_reason { :expired }
    end

    trait :voided do
      status { :voided }
      voided_at { Time.current }
      void_reason { :manual }
    end

    trait :expired_yesterday do
      status { :generated }
      expires_at { 1.day.ago }
    end

    trait :expiring_tomorrow do
      status { :generated }
      expires_at { 1.day.from_now }
    end
  end
end
