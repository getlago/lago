# frozen_string_literal: true

# Usage:
#
#   # Execute an operation idempotently
#   Idempotency.transaction do
#     Idempotency.unique!(invoice, date: invoice.date, customer_id: invoice.customer_id)

#     # Perform your business logic here
#     result = perform_operation
#   end
class Idempotency
  # Thread-local storage for the current transaction
  thread_mattr_accessor :current_transaction

  class IdempotencyError < StandardError; end

  # Represents a transaction context for an idempotent operation
  class Transaction
    attr_accessor :idempotent_resources

    def initialize
      @idempotent_resources = Hash.new { |k, v| k[v] = {} }
    end

    def ensure_idempotent!
      idempotent_resources.each do |resource, values|
        # generate the idempotency key for this resource
        idempotency_key = IdempotencyRecords::KeyService.call!(**values).idempotency_key

        # try and generate a resource
        result = IdempotencyRecords::CreateService.call(
          idempotency_key:,
          resource:
        )
        if result.failure?
          msg = "Idempotency key already exists for resource [#{resource.to_gid}] based on #{values.inspect}."
          Rails.logger.warn(msg)
          raise IdempotencyError.new(msg)
        end
      end
    end

    # Validates that at least one component has been added
    def valid?
      !idempotent_resources.empty?
    end
  end

  # Executes a block within an idempotent transaction.
  # use Idempotency.unique! to mark resources as unique
  #
  # This method wraps the execution in a database transaction to ensure
  # atomicity of the operations performed within the block.
  #
  # @yield A block that contains idempotent operations
  # @return [Object] The result of the block or the existing resource if the operation is idempotent
  # @raise [Exception] If an error occurs during the block execution
  # @raise [ArgumentError] If no components are added to generate an idempotency key
  def self.transaction
    # Create a new transaction context
    self.current_transaction = Transaction.new

    if ApplicationRecord.connection.open_transactions > 0
      raise ArgumentError, "An idempotent_transaction cannot be created in a transaction. (#{ApplicationRecord.connection.open_transactions} open transactions)"
    end

    # Ensure the transaction context is cleaned up even if an exception occurs
    ActiveRecord::Base.transaction do
      # Execute the block first to collect components
      begin
        original_return = yield
        transaction_completed = true
      rescue => e
        transaction_completed = true
        raise e
      ensure
        raise IdempotencyError.new("You've returned early from an Idempotency transaction, please use `next` instead") unless transaction_completed
      end

      # Validate that at least one component was added
      unless current_transaction.valid?
        raise ArgumentError, "At least one resource must be added"
      end

      current_transaction.ensure_idempotent!

      original_return
    ensure
      # Clean up the transaction context
      self.current_transaction = nil
    end
  end

  # Adds a resource to the idempotency key generation.
  # This method can only be called within an Idempotency.transaction block.
  #
  # @param resource [Object] Which resource we're guaranteeing uniqueness for
  # @raise [ArgumentError] If called outside of a transaction block
  def self.unique!(resource, **values)
    raise ArgumentError, "Idempotency.unique! can only be called within an idempotent_transaction block" unless current_transaction
    raise ArgumentError, "Idempotency.unique! expects keyword arguments" if values.empty?

    current_transaction.idempotent_resources[resource].merge!(values)
  end
end
