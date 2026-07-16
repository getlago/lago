# frozen_string_literal: true

require "rubocop"

module Cops
  class ServiceCallCop < ::RuboCop::Cop::Base
    def_node_matcher :base_service_subclass?, <<~PATTERN
      (const {nil? cbase} :BaseService)
    PATTERN

    def_node_matcher :call_method?, <<~PATTERN
      (def :call ...)
    PATTERN

    MSG = "Subclasses of Baseservice should have #call without arguments"

    def self.badge
      @badge ||= ::RuboCop::Cop::Badge.for("Lago::ServiceCall") # rubocop:disable ThreadSafety/ClassInstanceVariable
    end

    def on_def(node)
      return unless inherits_base_service?(node)
      return unless call_method?(node)
      return unless node.arguments?
      return if node.block_argument? && node.arguments.size == 1

      add_offense(node)
    end
    alias_method :on_defs, :on_def

    private

    def inherits_base_service?(node)
      node.each_ancestor(:class).any? { |class_node| base_service_subclass?(class_node.parent_class) }
    end
  end
end
