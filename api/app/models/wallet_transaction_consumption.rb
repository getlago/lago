# frozen_string_literal: true

class WalletTransactionConsumption < ApplicationRecord
  belongs_to :organization
  belongs_to :inbound_wallet_transaction, class_name: "WalletTransaction", inverse_of: :consumptions
  belongs_to :outbound_wallet_transaction, class_name: "WalletTransaction", inverse_of: :fundings

  validates :consumed_amount_cents, numericality: {greater_than: 0}
  validate :inbound_transaction_must_be_inbound
  validate :outbound_transaction_must_be_outbound

  def credit_amount
    wallet = outbound_wallet_transaction.wallet
    currency = wallet.currency_for_balance
    consumed_amount_cents.fdiv(currency.subunit_to_unit).fdiv(wallet.rate_amount).to_s
  end

  private

  def inbound_transaction_must_be_inbound
    return if inbound_wallet_transaction.nil?
    return if inbound_wallet_transaction.inbound?

    errors.add(:inbound_wallet_transaction, :invalid)
  end

  def outbound_transaction_must_be_outbound
    return if outbound_wallet_transaction.nil?
    return if outbound_wallet_transaction.outbound?

    errors.add(:outbound_wallet_transaction, :invalid)
  end
end

# == Schema Information
#
# Table name: wallet_transaction_consumptions
# Database name: primary
#
#  id                             :uuid             not null, primary key
#  consumed_amount_cents          :bigint           not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  inbound_wallet_transaction_id  :uuid             not null
#  organization_id                :uuid             not null
#  outbound_wallet_transaction_id :uuid             not null
#
# Indexes
#
#  idx_on_inbound_wallet_transaction_id_e54d00758d           (inbound_wallet_transaction_id)
#  idx_on_outbound_wallet_transaction_id_cf6ff733c6          (outbound_wallet_transaction_id)
#  idx_wallet_tx_consumptions_inbound_outbound               (inbound_wallet_transaction_id,outbound_wallet_transaction_id) UNIQUE
#  index_wallet_transaction_consumptions_on_organization_id  (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (inbound_wallet_transaction_id => wallet_transactions.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (outbound_wallet_transaction_id => wallet_transactions.id)
#
