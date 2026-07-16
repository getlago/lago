# frozen_string_literal: true

namespace :filters do
  desc "Clean duplicated filters"
  task deduplicate: :environment do
    charges = Charge.joins(:filters).includes(filters: {values: :billable_metric_filter}).distinct

    charges.find_each do |charge|
      next if charge.filters.count <= 1

      charge.filters.each do |filter|
        h = filter.to_h
        next if filter.reload.deleted_at.present?

        duplicates = charge.filters.select do |f|
          next false if f.id == filter.id
          next false if f.reload.deleted_at.present?

          h.keys.sort == f.to_h.keys.sort && h.keys.all? { |k| h[k].sort == f.to_h[k].sort }
        end

        duplicates.each { |f| f.discard! }
      end
    end
  end
end
