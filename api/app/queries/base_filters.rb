# frozen_string_literal: true

class BaseFilters
  def self.[](*attributes)
    Class.new(BaseFilters) { attr_accessor(*attributes) }
  end

  def initialize(**args)
    @filters = args
      .select { |key, _| self.class.method_defined?(key.to_sym) }
      .to_h
      .with_indifferent_access

    @filters.each { |key, value| send("#{key}=", value) }
  end

  attr_reader :filters

  delegate :[], :key?, to: :filters

  def to_h
    filters
  end
end
