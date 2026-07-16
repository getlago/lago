# frozen_string_literal: true

namespace :fees do
  desc "Fill missing fee_type"
  task fill_fee_type: :environment do
    Fee.where(fee_type: nil).find_each do |fee|
      next fee.add_on! if fee.applied_add_on_id.present?
      next fee.charge! if fee.charge_id.present?

      fee.subscription!
    end
  end
end
