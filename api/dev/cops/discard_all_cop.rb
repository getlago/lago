# frozen_string_literal: true

require "rubocop"

module Cops
  class DiscardAllCop < ::RuboCop::Cop::Base
    MSG = "Avoid using `discard_all`. Use `update_all(deleted_at: Time.current)` instead."

    def_node_matcher :discard_all_call?, <<~PATTERN
      (send _ :discard_all ...)
    PATTERN

    def self.badge
      @badge ||= ::RuboCop::Cop::Badge.for("Lago/DiscardAll") # rubocop:disable ThreadSafety/ClassInstanceVariable
    end

    def on_send(node)
      return unless discard_all_call?(node)

      add_offense(node)
    end
  end
end
