# frozen_string_literal: true

class DottedHash < Hash
  attr_reader :separator

  def initialize(hash = {}, separator: ".")
    super()
    @separator = separator
    to_dotted_hash(hash, recursive_key: "")
  end

  private

  def to_dotted_hash(hash, recursive_key: "")
    hash.each do |k, v|
      key = recursive_key + k.to_s
      if v.is_a?(Hash)
        to_dotted_hash(v, recursive_key: key + separator)
      else
        self[key] = v
      end
    end
  end
end
