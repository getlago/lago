# frozen_string_literal: true

class WalletTransactionConsumptionsQuery < BaseQuery
  Result = BaseResult[:wallet_transaction_consumptions]
  Filters = BaseFilters[:wallet_transaction_id, :direction]

  def call
    return result unless validate_filters.success?
    return result.not_found_failure!(resource: "wallet_transaction") unless wallet_transaction
    return result.single_validation_failure!(field: :wallet, error_code: "not_traceable") unless wallet_transaction.wallet.traceable?
    return result.single_validation_failure!(field: :transaction_type, error_code: "invalid_transaction_type") unless valid_transaction_type?

    consumptions = wallet_transaction.public_send(direction).includes(eager_load_association)
    consumptions = paginate(consumptions)
    consumptions = apply_consistent_ordering(consumptions)

    result.wallet_transaction_consumptions = consumptions
    result
  end

  private

  def direction
    filters.direction
  end

  def wallet_transaction
    @wallet_transaction ||= organization.wallet_transactions.find_by(id: filters.wallet_transaction_id)
  end

  def filters_contract
    @filters_contract ||= Queries::WalletTransactionConsumptionsQueryFiltersContract.new
  end

  def valid_transaction_type?
    case direction.to_sym
    when :consumptions
      wallet_transaction.inbound?
    when :fundings
      wallet_transaction.outbound?
    end
  end

  def eager_load_association
    case direction.to_sym
    when :consumptions
      {outbound_wallet_transaction: :wallet}
    when :fundings
      {inbound_wallet_transaction: :wallet}
    end
  end
end
