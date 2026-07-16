# frozen_string_literal: true

module Sequenced
  extend ActiveSupport::Concern

  included do
    scope :with_sequential_id, -> { where.not(sequential_id: nil) }

    before_save :ensure_sequential_id

    private

    def ensure_sequential_id
      return if sequential_id.present?
      return unless should_assign_sequential_id?

      self.sequential_id = generate_sequential_id
    end

    def should_assign_sequential_id?
      true
    end

    def generate_sequential_id
      acquire_advisory_lock!

      (sequence_scope.maximum(:sequential_id) || 0) + 1
    end

    def acquire_advisory_lock!
      conn = self.class.connection
      raise SequenceError, "must be called inside a transaction" unless conn.transaction_open?

      quoted_key = conn.quote(lock_key_value)
      conn.execute("SET LOCAL lock_timeout = '10s'")
      conn.execute("SELECT pg_advisory_xact_lock(hashtext(#{quoted_key}))")
    rescue ActiveRecord::LockWaitTimeout
      raise SequenceError, "Unable to acquire lock on the database"
    end

    def sequence_scope
      self.class.class_exec(self, &self.class.sequenced_options[:scope])
    end

    def lock_key_value
      "#{self.class.class_exec(self, &self.class.sequenced_lock_key) || self.class.name.underscore}_lock"
    end
  end

  class_methods do
    def sequenced(scope:, lock_key: nil)
      self.sequenced_options = {scope:}
      self.sequenced_lock_key = lock_key
    end

    # rubocop:disable ThreadSafety/ClassInstanceVariable
    def sequenced_options=(options)
      @sequenced_options = options
    end

    def sequenced_options
      @sequenced_options
    end

    def sequenced_lock_key=(lock_key)
      @sequenced_lock_key = lock_key
    end

    def sequenced_lock_key
      @sequenced_lock_key
    end
    # rubocop:enable ThreadSafety/ClassInstanceVariable
  end

  class SequenceError < StandardError; end
end
