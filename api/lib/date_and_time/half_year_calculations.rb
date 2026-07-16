# frozen_string_literal: true

module DateAndTime
  module HalfYearCalculations
    def beginning_of_half_year
      # If month is 1–6 → snap to 1 (January)
      # If month is 7–12 → snap to 7 (July)
      first_half_year_month = (month <= 6) ? 1 : 7
      beginning_of_month.change(month: first_half_year_month)
    end
    alias_method :at_beginning_of_half_year, :beginning_of_half_year

    def end_of_half_year
      last_half_year_month = (month <= 6) ? 6 : 12
      beginning_of_month.change(month: last_half_year_month).end_of_month
    end
    alias_method :at_end_of_half_year, :end_of_half_year
  end
end
