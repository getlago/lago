# frozen_string_literal: true

FactoryBot.define do
  factory :password_reset do
    user

    token { SecureRandom.hex(20) }
    expire_at { Time.current + 30.minutes }
  end
end
