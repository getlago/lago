# frozen_string_literal: true

# spec/support/matchers/be_soft_deletable.rb
RSpec::Matchers.define :be_soft_deletable do
  match do |model_class|
    @model_class = model_class

    includes_discard_model? && has_correct_discard_column? && has_correct_default_scope?
  end

  failure_message do |model_class|
    messages = []

    unless includes_discard_model?
      messages << "expected #{model_class} to include Discard::Model"
    end

    unless has_correct_discard_column?
      messages << "expected #{model_class}.discard_column to eq :deleted_at, but got #{@model_class.discard_column.inspect}"
    end

    unless has_correct_default_scope?
      messages << "expected #{model_class} to have a default scope that keeps only undiscarded records"
    end

    messages.join(" and ")
  end

  failure_message_when_negated do |model_class|
    "expected #{model_class} not to be soft deletable"
  end

  description do
    "be soft deletable (include Discard::Model, have discard_column set to :deleted_at, and have default scope for undiscarded records)"
  end

  private

  def includes_discard_model?
    @model_class.included_modules.include?(Discard::Model)
  end

  def has_correct_discard_column?
    @model_class.respond_to?(:discard_column) && @model_class.discard_column.to_sym == :deleted_at
  end

  def has_correct_default_scope?
    return false unless @model_class.respond_to?(:discard_column)

    # Get the default scope's where clause
    default_scope_sql = @model_class.all.to_sql
    discard_column = @model_class.discard_column

    # Check if the default scope includes a WHERE clause that filters out discarded records
    # This checks for the pattern: WHERE "table_name"."discard_column" IS NULL
    table_name = @model_class.table_name
    expected_condition = "\"#{table_name}\".\"#{discard_column}\" IS NULL"

    default_scope_sql.include?(expected_condition)
  end
end
