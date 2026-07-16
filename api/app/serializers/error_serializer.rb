# frozen_string_literal: true

class ErrorSerializer
  attr_reader :error

  def initialize(error)
    @error = error
  end

  def serialize
    {
      message: error.message
    }
  end
end
