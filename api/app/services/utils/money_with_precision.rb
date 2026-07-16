# frozen_string_literal: true

module Utils
  class MoneyWithPrecision < Money
    self.default_infinite_precision = true
  end
end
