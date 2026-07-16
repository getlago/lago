# frozen_string_literal: true

require "rubocop"

module Cops
  class NoDropColumnOrTableCop < ::RuboCop::Cop::Base
    MSG = "Dropping columns or tables is disabled due to the risks involved. " \
          "See docs/dropping_columns_and_tables.md for more information."

    FORBIDDEN_METHODS = %i[remove_column drop_table remove_columns].freeze

    # Matches direct calls like `remove_column :users, :email`
    def_node_matcher :forbidden_migration_method?, <<~PATTERN
      (send nil? {#{FORBIDDEN_METHODS.map { |m| ":#{m}" }.join(" ")}} ...)
    PATTERN

    # Matches calls on a receiver like `t.remove_column :email` inside change_table blocks
    def_node_matcher :forbidden_table_method?, <<~PATTERN
      (send _ {#{FORBIDDEN_METHODS.map { |m| ":#{m}" }.join(" ")}} ...)
    PATTERN

    def self.badge
      @badge ||= ::RuboCop::Cop::Badge.for("Lago/NoDropColumnOrTable") # rubocop:disable ThreadSafety/ClassInstanceVariable
    end

    def on_send(node)
      return unless forbidden_migration_method?(node) || forbidden_table_method?(node)

      add_offense(node)
    end
  end
end
