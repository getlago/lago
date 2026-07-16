# frozen_string_literal: true

# app/services/wallets/build_allocation_rules_service.rb
module Wallets
  class BuildAllocationRulesService < BaseService
    Result = BaseResult[:allocation_rules]

    def initialize(customer:)
      @customer = customer
      super
    end

    ##
    # Build allocation hash by priority of all the wallets
    # if wallet is in the first position of the hash means is the one with most priority
    # example of the result
    # ( we store the wallets ids and billable metric ids, used names on the example to easy reading)
    #
    # wallet1:
    # 	unrestricted
    # wallet2:
    # 	targets: bm1
    # wallet3:
    #     type: charges
    # wallet4:
    # 	unrestricted
    # wallet5:
    #     targets: bm2
    # wallet6:
    #     type: charges

    #   bm_map = bm1: [wallet1 ,wallet2 wallet3, wallet4, wallet6]
    #            bm2: [wallet1, wallet3, wallet4, wallet5, wallet6]
    #   type_map      = charges: [wallet1, wallet3, wallet4 wallet6]
    #   unrestricted  = [wallet1, wallet4]
    def call
      bm_map = Hash.new { |h, k| h[k] = [] }
      type_map = Hash.new { |h, k| h[k] = [] }
      unrestricted = []
      wallet_currencies = {}

      wallets.each do |wallet|
        wallet_currencies[wallet.id] = wallet.balance_currency

        if wallet.wallet_targets.any?
          handle_billable_metric_wallet(wallet, bm_map, type_map, unrestricted)
        elsif wallet.allowed_fee_types.present?
          handle_fee_type_wallet(wallet, bm_map, type_map, unrestricted)
        else
          handle_unrestricted_wallet(wallet, bm_map, type_map, unrestricted)
        end
      end

      result.allocation_rules = {bm_map:, type_map:, unrestricted:, wallet_currencies:}
      result
    end

    private

    attr_reader :customer

    def add_unique(array, id)
      array << id unless array.include?(id)
    end

    # Add multiple items uniquely to target array
    def add_all_unique(target_array, source_array)
      source_array.each { |id| add_unique(target_array, id) }
    end

    def wallets
      @wallets ||= customer.wallets.active.in_application_order
        .includes(wallet_targets: :billable_metric)
    end

    def handle_billable_metric_wallet(wallet, bm_map, type_map, unrestricted)
      wallet.wallet_targets.each do |wallet_target|
        metric_wallets = bm_map[wallet_target.billable_metric_id]

        # add what we already can have from the higher priority arrays
        add_all_unique(metric_wallets, type_map["charge"])
        add_all_unique(metric_wallets, unrestricted)
        add_unique(metric_wallets, wallet.id)
      end
    end

    def handle_fee_type_wallet(wallet, bm_map, type_map, unrestricted)
      Array(wallet.allowed_fee_types).each do |fee_type|
        fee_type_wallets = type_map[fee_type]
        # add what we already can have from the higher priority arrays
        add_all_unique(fee_type_wallets, unrestricted)
        add_unique(fee_type_wallets, wallet.id)

        # Charge fee types also apply to all billable metric mappings
        bm_map.each_value { |wallets| add_unique(wallets, wallet.id) } if fee_type == "charge"
      end
    end

    def handle_unrestricted_wallet(wallet, bm_map, type_map, unrestricted)
      # Unrestricted wallets apply to everything
      add_unique(unrestricted, wallet.id)
      bm_map.each_value { |wallets| add_unique(wallets, wallet.id) }
      type_map.each_value { |wallets| add_unique(wallets, wallet.id) }
    end
  end
end
