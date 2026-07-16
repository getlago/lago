# frozen_string_literal: true

class IntervalHelper
  def self.interval_name(interval)
    case interval.to_sym
    when :weekly
      I18n.t("invoice.week")
    when :monthly
      I18n.t("invoice.month")
    when :yearly
      I18n.t("invoice.year")
    when :quarterly
      I18n.t("invoice.quarter")
    when :semiannual
      I18n.t("invoice.half_year")
    end
  end
end
