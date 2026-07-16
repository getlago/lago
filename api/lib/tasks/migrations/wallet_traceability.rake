# frozen_string_literal: true

require "csv"
require "parallel"

class WalletMigration
  def self.default_error_log_file
    File.join(Dir.tmpdir, "wallet_migration_errors_#{Time.current.strftime("%Y%m%d%H%M%S")}.csv")
  end

  def initialize(dry_run: true, limit: nil, batch_size: 1000, error_display_limit: 50,
    thread_count: 0, error_log_file: nil, cursor: nil, scope: Wallet.where(traceable: false))
    @scope = scope
    @dry_run = dry_run
    @limit = limit
    @batch_size = limit ? [batch_size, limit].min : batch_size
    @error_display_limit = error_display_limit
    @thread_count = thread_count
    @error_log_file = error_log_file || self.class.default_error_log_file
    validate_error_log_file!
    parse_cursor(cursor)
  end

  def run
    puts "Wallet migration — mode: #{@dry_run ? "DRY-RUN (validation only)" : "BACKFILL (writing data)"}"
    puts "Customer limit: #{@limit || "all"}, Batch size: #{@batch_size}, Threads: #{@thread_count.zero? ? "sequential" : @thread_count}"
    puts "Cursor: #{@cursor_start}"
    if @limit
      puts "Next cursor: #{@next_cursor_start || "none (all remaining records fit within limit)"}"
    end
    puts "=" * 60

    if @dry_run
      run_validation
    else
      run_backfill
    end
  end

  private

  attr_reader :scope

  def validate_error_log_file!
    FileUtils.touch(@error_log_file)
  rescue SystemCallError => e
    raise "Cannot write to error log file #{@error_log_file}: #{e.message}"
  end

  UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  def parse_cursor(cursor)
    if cursor
      raise "Invalid CURSOR format: #{cursor}" unless cursor.match?(UUID_REGEX)

      @cursor_start = cursor
    else
      @cursor_start = scope.order(:customer_id).pick(:customer_id)
    end

    @next_cursor_start = compute_next_cursor
  end

  def compute_next_cursor
    return unless @limit

    query = scope
    query = query.where(Wallet.arel_table[:customer_id].gteq(@cursor_start)) if @cursor_start
    query.order(:customer_id).select(:customer_id).distinct
      .offset(@limit).limit(1).pick(:customer_id)
  end

  # ---------------------------------------------------------------------------
  # Dry-run: validate without writing
  # ---------------------------------------------------------------------------

  def run_validation
    mutex = Mutex.new
    total_wallets = 0
    customers_validated = 0
    migratable_wallets = 0
    problematic_wallets = []
    progress_total = progress_count

    iterate_customers_in_batches do |customer_ids|
      Parallel.each(customer_ids, in_threads: @thread_count) do |customer_id|
        ActiveRecord::Base.connection_pool.with_connection do
          wallets = scope.where(customer_id: customer_id).includes(:customer, :organization, :wallet_transactions).to_a
          wallets.each do |wallet|
            issues = validate_wallet(wallet)
            mutex.synchronize do
              total_wallets += 1
              if issues.empty?
                migratable_wallets += 1
              else
                problematic_wallets << build_wallet_error(wallet, issues)
              end
            end
          end
          mutex.synchronize { customers_validated += 1 }
        end
      end
      mutex.synchronize { print_progress("Validating", customers_validated, progress_total) }
    end

    clear_progress
    print_validation_summary(total_wallets, migratable_wallets, problematic_wallets)
  end

  def settled_inbound(wallet)
    wallet.wallet_transactions.select { |tx| tx.inbound? && tx.settled? }.sort_by(&:created_at)
  end

  def settled_outbound(wallet)
    wallet.wallet_transactions.select { |tx| tx.outbound? && tx.settled? }.sort_by(&:created_at)
  end

  def validate_wallet(wallet)
    issues = []

    # Check wallet-level issues
    if wallet.balance_cents < 0
      issues << "Negative wallet balance: #{wallet.balance_cents} cents"
    end

    # Check transaction-level issues
    validate_transactions(wallet, issues)

    # Simulate FIFO consumption and check for issues
    simulation_result = simulate_fifo_consumption(wallet, issues)

    # Check balance drift
    drift = wallet.balance_cents - simulation_result[:final_balance]
    if drift != 0
      issues << if drift.abs < 100
        "Balance drift < 1 unit: #{drift} cents (wallet: #{wallet.balance_cents}, simulated: #{simulation_result[:final_balance]}) — likely rounding"
      else
        "Balance drift >= 1 unit: #{drift} cents (wallet: #{wallet.balance_cents}, simulated: #{simulation_result[:final_balance]})"
      end
    end

    issues
  end

  def validate_transactions(wallet, issues)
    settled_inbound(wallet).each do |tx|
      amount = tx.amount_cents
      if amount != amount.to_i
        issues << "Decimal amount_cents on inbound #{tx.id}: #{amount} (expected integer)"
      end
      if amount < 0
        issues << "Negative amount_cents on inbound #{tx.id}: #{amount}"
      end
    end

    settled_outbound(wallet).each do |tx|
      amount = tx.amount_cents
      if amount != amount.to_i
        issues << "Decimal amount_cents on outbound #{tx.id}: #{amount} (expected integer)"
      end
      if amount < 0
        issues << "Negative amount_cents on outbound #{tx.id}: #{amount}"
      end
    end
  end

  def simulate_fifo_consumption(wallet, issues)
    inbound_txs = settled_inbound(wallet)
    outbound_txs = settled_outbound(wallet)

    if outbound_txs.any? && inbound_txs.empty?
      issues << "No inbound transactions found but #{outbound_txs.size} outbound exist — missing transaction history"
      return {final_balance: 0}
    end

    # Pre-sort inbound by consumption priority (stable across all outbound)
    sorted_inbound = inbound_txs.map do |tx|
      {id: tx.id, remaining: tx.amount_cents, transaction_status: tx.transaction_status,
       priority: tx.priority || 0, created_at: tx.created_at}
    end.sort_by { |d| [(d[:transaction_status] == "granted") ? 0 : 1, d[:priority], d[:created_at]] }

    # Index for newly eligible inbound (sorted by created_at for eligibility check)
    inbound_by_time = inbound_txs.map do |tx|
      {id: tx.id, created_at: tx.created_at}
    end.sort_by { |d| d[:created_at] }
    time_cursor = 0
    eligible_ids = Set.new

    # Remaining balance lookup
    sorted_inbound.index_by { |d| d[:id] }

    outbound_txs.each do |outbound|
      amount_to_consume = outbound.amount_cents
      next if amount_to_consume <= 0

      # Advance eligibility cursor — inbound created_at <= outbound created_at
      while time_cursor < inbound_by_time.size && inbound_by_time[time_cursor][:created_at] <= outbound.created_at
        eligible_ids.add(inbound_by_time[time_cursor][:id])
        time_cursor += 1
      end

      available = sorted_inbound.select { |d| eligible_ids.include?(d[:id]) && d[:remaining] > 0 }

      if available.empty?
        issues << "Outbound #{outbound.id} (#{outbound.created_at.to_date}): no inbound transactions available — missing transaction history"
        next
      end

      total_available = available.sum { |d| d[:remaining] }

      available.each do |data|
        break if amount_to_consume <= 0

        consume_amount = [data[:remaining], amount_to_consume].min
        data[:remaining] -= consume_amount
        amount_to_consume -= consume_amount
      end

      if amount_to_consume > 0
        issues << "Outbound #{outbound.id} (#{outbound.created_at.to_date}): insufficient inbound to consume #{outbound.amount_cents} cents " \
                  "(available: #{total_available} cents, shortfall: #{amount_to_consume} cents)"
      end
    end

    final_balance = sorted_inbound.sum { |d| d[:remaining] }

    {final_balance: final_balance}
  end

  def print_validation_summary(total_wallets, migratable_wallets, problematic_wallets)
    puts "\n" + "=" * 60
    puts "Total wallets: #{total_wallets}"
    puts "Migratable: #{migratable_wallets}"
    puts "Problematic: #{problematic_wallets.size}"

    if problematic_wallets.any?
      puts "\n" + "=" * 60
      puts "PROBLEMATIC WALLETS (first #{@error_display_limit}):"
      problematic_wallets.first(@error_display_limit).each do |pw|
        puts "  Wallet #{pw[:wallet_id]}:"
        puts "    - Customer: #{pw[:customer_name]} (#{pw[:customer_id]})"
        puts "    - Org: #{pw[:organization_name]} (#{pw[:organization_id]})"
        puts "    - Created At: #{pw[:created_at].to_date}"
        puts "    - Issues:"
        pw[:issues].first(3).each { |issue| puts "      - #{issue}" }
        remaining = pw[:issues].size - 3
        puts "      - ... and #{remaining} more issues" if remaining > 0
      end
      hidden = problematic_wallets.size - @error_display_limit
      puts "  ... and #{hidden} more problematic wallets" if hidden > 0
    end

    puts "\n" + "=" * 60
    percentage = (total_wallets > 0) ? (migratable_wallets.to_f / total_wallets * 100).round(2) : 0
    puts "Migration readiness: #{percentage}%"

    if @error_log_file && problematic_wallets.any?
      export_csv(problematic_wallets, headers: %w[wallet_id customer_id customer_name organization_id organization_name created_at issues]) do |pw|
        [pw[:wallet_id], pw[:customer_id], pw[:customer_name], pw[:organization_id], pw[:organization_name], pw[:created_at].to_date, pw[:issues].join(" | ")]
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Backfill: write data
  # ---------------------------------------------------------------------------

  def run_backfill
    mutex = Mutex.new
    customers_processed = 0
    wallets_processed = 0
    errored_wallets = []
    progress_total = progress_count

    iterate_customers_in_batches do |customer_ids|
      Parallel.each(customer_ids, in_threads: @thread_count) do |customer_id|
        ActiveRecord::Base.connection_pool.with_connection do
          customer = Customer.new(id: customer_id).freeze
          current_wallet = nil
          ApplicationRecord.transaction do
            Customers::LockService.call(customer:, scope: :prepaid_credit) do
              wallets = scope.where(customer_id: customer_id).includes(:customer, :organization, wallet_transactions: :fundings).to_a
              next if wallets.empty?

              wallets.each do |wallet|
                current_wallet = wallet
                issues = validate_wallet(wallet)
                if issues.any?
                  raise issues.join("; ")
                end

                backfill_wallet_transactions(wallet)
              end

              Wallet.where(id: wallets.map(&:id)).update_all(traceable: true) # rubocop:disable Rails/SkipsModelValidations

              mutex.synchronize do
                wallets_processed += wallets.size
                customers_processed += 1
              end
            end
          rescue => e
            mutex.synchronize do
              errored_wallets << build_wallet_error(current_wallet, [e.message])
            end
            raise ActiveRecord::Rollback
          end
        end
      end
      mutex.synchronize { print_progress("Backfilling", customers_processed + errored_wallets.size, progress_total) }
    end

    clear_progress
    print_backfill_summary(customers_processed, wallets_processed, errored_wallets)
  end

  def backfill_wallet_transactions(wallet)
    inbound_txs = settled_inbound(wallet)

    # Step 1: Initialize all settled inbound transactions with full amount
    inbound_txs.each do |tx|
      next if tx.remaining_amount_cents.present?
      tx.update_column(:remaining_amount_cents, tx.amount_cents) # rubocop:disable Rails/SkipsModelValidations
    end

    # Pre-sort inbound by consumption priority (stable across all outbound)
    sorted_inbound = inbound_txs.map do |tx|
      {id: tx.id, transaction: tx, remaining: tx.amount_cents, transaction_status: tx.transaction_status,
       priority: tx.priority || 0, created_at: tx.created_at}
    end.sort_by { |d| [(d[:transaction_status] == "granted") ? 0 : 1, d[:priority], d[:created_at]] }

    # Index for newly eligible inbound (sorted by created_at for eligibility check)
    inbound_by_time = inbound_txs.sort_by(&:created_at)
    time_cursor = 0
    eligible_ids = Set.new

    # Step 2: Process settled outbound transactions in chronological order
    settled_outbound(wallet).each do |outbound|
      next if outbound.fundings.any?

      amount_to_consume = outbound.amount_cents
      next if amount_to_consume <= 0

      # Advance eligibility cursor
      while time_cursor < inbound_by_time.size && inbound_by_time[time_cursor].created_at <= outbound.created_at
        eligible_ids.add(inbound_by_time[time_cursor].id)
        time_cursor += 1
      end

      consumption_records = []

      sorted_inbound.each do |data|
        break if amount_to_consume <= 0
        next unless eligible_ids.include?(data[:id]) && data[:remaining] > 0

        consume_amount = [data[:remaining], amount_to_consume].min

        consumption_records << {
          organization_id: wallet.organization_id,
          inbound_wallet_transaction_id: data[:id],
          outbound_wallet_transaction_id: outbound.id,
          consumed_amount_cents: consume_amount,
          created_at: outbound.created_at,
          updated_at: Time.current
        }

        data[:remaining] -= consume_amount
        amount_to_consume -= consume_amount
      end

      if amount_to_consume > 0
        raise "Wallet #{wallet.id}: Could not fully consume outbound #{outbound.id}, #{amount_to_consume} cents remaining"
      end

      WalletTransactionConsumption.insert_all!(consumption_records) if consumption_records.any? # rubocop:disable Rails/SkipsModelValidations
    end

    # Step 3: Update remaining_amount_cents based on final state
    sorted_inbound.each do |data|
      data[:transaction].update_column(:remaining_amount_cents, data[:remaining]) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def build_wallet_error(wallet, issues)
    {
      wallet_id: wallet&.id || "unknown",
      customer_id: wallet&.customer_id || "unknown",
      customer_name: wallet&.customer&.name || "unknown",
      organization_id: wallet&.organization_id || "unknown",
      organization_name: wallet&.organization&.name || "unknown",
      created_at: wallet&.created_at,
      issues: issues
    }
  end

  def print_backfill_summary(customers_processed, wallets_processed, errored_wallets)
    puts "\n" + "=" * 60
    puts "Customers processed: #{customers_processed}"
    puts "Wallets processed: #{wallets_processed}"
    puts "Errors: #{errored_wallets.size}"

    if errored_wallets.any?
      puts "\nErrors (first #{@error_display_limit}):"
      errored_wallets.first(@error_display_limit).each do |pw|
        puts "  Wallet #{pw[:wallet_id]}:"
        puts "    - Customer: #{pw[:customer_name]} (#{pw[:customer_id]})"
        puts "    - Org: #{pw[:organization_name]} (#{pw[:organization_id]})"
        puts "    - Created At: #{pw[:created_at]&.to_date}"
        puts "    - Issues:"
        pw[:issues].first(3).each { |issue| puts "      - #{issue}" }
        remaining = pw[:issues].size - 3
        puts "      - ... and #{remaining} more issues" if remaining > 0
      end
      hidden = errored_wallets.size - @error_display_limit
      puts "  ... and #{hidden} more errored wallets" if hidden > 0
    end

    if @error_log_file && errored_wallets.any?
      export_csv(errored_wallets, headers: %w[wallet_id customer_id customer_name organization_id organization_name created_at issues]) do |pw|
        [pw[:wallet_id], pw[:customer_id], pw[:customer_name], pw[:organization_id], pw[:organization_name], pw[:created_at]&.to_date, pw[:issues].join(" | ")]
      end
    end
  end

  # ---------------------------------------------------------------------------
  # CSV export
  # ---------------------------------------------------------------------------

  def export_csv(records, headers:)
    CSV.open(@error_log_file, "w") do |csv|
      csv << headers
      records.each { |record| csv << yield(record) }
    end
    puts "CSV exported to #{@error_log_file} (#{records.size} records)"
  end

  # ---------------------------------------------------------------------------
  # Shared helpers
  # ---------------------------------------------------------------------------

  def windowed_scope
    query = scope
    query = query.where(Wallet.arel_table[:customer_id].gteq(@cursor_start)) if @cursor_start
    query = query.where(Wallet.arel_table[:customer_id].lt(@next_cursor_start)) if @next_cursor_start
    query
  end

  def progress_count
    windowed_scope.select(:customer_id).distinct.count
  end

  # Iterates distinct customer IDs in batches using cursor-based pagination.
  # The window is bounded by @cursor_start (inclusive) and @next_cursor_start (exclusive).
  def iterate_customers_in_batches
    last_customer_id = nil

    loop do
      query = windowed_scope
      query = query.where(Wallet.arel_table[:customer_id].gt(last_customer_id)) if last_customer_id
      customer_ids = query.order(:customer_id).distinct.limit(@batch_size).pluck(:customer_id)
      break if customer_ids.empty?

      last_customer_id = customer_ids.last

      yield(customer_ids)
    end
  end

  def print_progress(label, current, total)
    return if total == 0

    percentage = (current.to_f / total * 100).round(1)
    bar_width = 30
    filled = (current.to_f / total * bar_width).round
    bar = "#" * filled + "-" * (bar_width - filled)
    print "\r#{label}: [#{bar}] #{current}/#{total} (#{percentage}%)"
  end

  def clear_progress
    print "\r" + " " * 80 + "\r"
  end
end

namespace :migrations do
  desc "Migrate wallets to traceable (DRY_RUN=true by default)"
  task wallet_traceability: :environment do
    Rails.logger.level = :info

    dry_run = ENV.fetch("DRY_RUN", "true") != "false"
    include_terminated = ENV["INCLUDE_TERMINATED"] == "true"
    scope = Wallet.where(traceable: false)
    scope = scope.active unless include_terminated
    scope = scope.where(organization_id: ENV["ORGANIZATION_ID"]) if ENV["ORGANIZATION_ID"].present?

    options = {scope:, dry_run:}
    options[:limit] = parse_positive_integer("LIMIT") if ENV["LIMIT"].present?
    options[:batch_size] = parse_positive_integer("BATCH_SIZE") if ENV["BATCH_SIZE"].present?
    options[:error_display_limit] = parse_positive_integer("ERROR_DISPLAY_LIMIT") if ENV["ERROR_DISPLAY_LIMIT"].present?
    options[:thread_count] = parse_non_negative_integer("THREAD_COUNT") if ENV["THREAD_COUNT"].present?
    options[:error_log_file] = ENV["ERROR_LOG_FILE"] if ENV["ERROR_LOG_FILE"].present?

    options[:cursor] = ENV["CURSOR"] if ENV["CURSOR"].present?

    WalletMigration.new(**options).run
  end

  def parse_positive_integer(name)
    value = ENV[name]
    integer = Integer(value)
    raise "#{name} must be a positive integer, got: #{value}" unless integer > 0
    integer
  rescue ArgumentError
    raise "#{name} must be a positive integer, got: #{value}"
  end

  def parse_non_negative_integer(name)
    value = ENV[name]
    integer = Integer(value)
    raise "#{name} must be a non-negative integer, got: #{value}" unless integer >= 0
    integer
  rescue ArgumentError
    raise "#{name} must be a non-negative integer, got: #{value}"
  end
end
