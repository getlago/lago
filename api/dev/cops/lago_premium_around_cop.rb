# frozen_string_literal: true

require "rubocop"

module Cops
  class LagoPremiumAroundCop < ::RuboCop::Cop::Base
    include ::RuboCop::Cop::RangeHelp
    extend ::RuboCop::Cop::AutoCorrector

    MSG = "Use `:premium` metadata on the context/describe block instead of `around { |test| lago_premium!(&test) }`."

    # Matches: lago_premium!(&var)
    def_node_matcher :lago_premium_call_with_block_pass?, <<~PATTERN
      (send nil? :lago_premium! (block_pass (lvar $_var_name)))
    PATTERN

    def self.badge
      @badge ||= ::RuboCop::Cop::Badge.for("Lago/LagoPremiumAround") # rubocop:disable ThreadSafety/ClassInstanceVariable
    end

    def on_send(node)
      var_name = lago_premium_call_with_block_pass?(node)
      return unless var_name

      around_block = find_parent_around_block(node)
      return unless around_block

      around_var = around_block.arguments.first&.name
      return unless around_var == var_name

      add_offense(node) do |corrector|
        if around_block.body == node
          remove_around_block(corrector, around_block)
        else
          corrector.replace(node, "#{var_name}.run")
        end
        add_premium_metadata_to_parent(corrector, around_block)
      end
    end

    private

    def remove_around_block(corrector, node)
      range = range_by_whole_lines(node.source_range, include_final_newline: true)

      # Also remove trailing blank line if present
      source = node.source_range.source_buffer.source
      next_pos = range.end_pos
      if next_pos < source.length
        next_newline = source.index("\n", next_pos)
        if next_newline
          next_line = source[next_pos...next_newline]
          if next_line.strip.empty?
            range = range.resize(range.size + next_newline - next_pos + 1)
          end
        end
      end

      corrector.remove(range)
    end

    def add_premium_metadata_to_parent(corrector, node)
      parent = find_parent_example_group(node)
      return unless parent
      return if has_premium_metadata?(parent)

      send_node = parent.send_node
      args = send_node.arguments

      # Insert before hash arguments to maintain valid Ruby syntax,
      # otherwise insert after the last argument
      hash_arg = args.find(&:hash_type?)
      if hash_arg
        corrector.insert_before(hash_arg, ":premium, ")
      else
        corrector.insert_after(send_node.last_argument, ", :premium")
      end
    end

    def find_parent_around_block(node)
      node.each_ancestor(:block).find do |ancestor|
        ancestor.method_name == :around && ancestor.send_node.receiver.nil?
      end
    end

    def find_parent_example_group(node)
      node.each_ancestor(:block).find do |ancestor|
        %i[context describe shared_examples shared_examples_for].include?(ancestor.method_name)
      end
    end

    def has_premium_metadata?(block_node)
      send_node = block_node.send_node
      send_node.arguments.any? do |arg|
        (arg.sym_type? && arg.value == :premium) ||
          (arg.hash_type? && arg.pairs.any? { |pair| pair.key.sym_type? && pair.key.value == :premium })
      end
    end
  end
end
