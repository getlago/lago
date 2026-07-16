# frozen_string_literal: true

module Analytics
  class GrossRevenuesService < BaseService
    def call
      @records = ::Analytics::GrossRevenue.find_all_by(organization.id, **filters)

      result.records = records
      result
    end
  end
end
