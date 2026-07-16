# frozen_string_literal: true

FactoryBot.define do
  factory :wallet_target, class: "WalletTarget" do
    wallet
    billable_metric
    organization { billable_metric&.organization || wallet&.organization || association(:organization) }
  end
end
