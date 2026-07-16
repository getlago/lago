# frozen_string_literal: true

class BaseResult
  include Result

  class_attribute :attributes, default: [] # rubocop:disable ThreadSafety/ClassAndModuleAttributes

  def self.[](*attributes)
    Class.new(BaseResult) do
      attr_accessor(*attributes)

      self.attributes = attributes
    end
  end

  def ==(other)
    return false unless other.class == self.class
    return false unless failure? == other.failure?
    return false unless other.error == error

    self.class.attributes.all? do |attribute|
      send(attribute) == other.send(attribute)
    end
  end
end
