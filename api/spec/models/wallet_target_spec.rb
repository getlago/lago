# frozen_string_literal: true

RSpec.describe WalletTarget do
  subject(:wallet_target) { build(:wallet_target) }

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:wallet) }
  it { is_expected.to belong_to(:billable_metric) }
end
