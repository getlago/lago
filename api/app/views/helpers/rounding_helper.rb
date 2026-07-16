# frozen_string_literal: true

class RoundingHelper
  def self.round_decimal_part(num, decimal_sig_figs = 6)
    return "0" if num.zero?
    return BigDecimal("%.#{decimal_sig_figs}g" % num).to_s if num.abs < 1

    rounded = BigDecimal(num.to_s).round(decimal_sig_figs)
    rounded.frac.zero? ? rounded.to_i.to_s : rounded.to_s
  end
end
