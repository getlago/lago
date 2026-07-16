# frozen_string_literal: true

FactoryBot.define do
  factory :user_device do
    user

    fingerprint { SecureRandom.hex(32) }
    last_logged_at { Time.current }
  end
end
