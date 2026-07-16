# frozen_string_literal: true

class WalletTarget < ApplicationRecord
  include PaperTrailTraceable

  belongs_to :wallet
  belongs_to :billable_metric
  belongs_to :organization
end

# == Schema Information
#
# Table name: wallet_targets
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  billable_metric_id :uuid             not null
#  organization_id    :uuid             not null
#  wallet_id          :uuid             not null
#
# Indexes
#
#  index_wallet_targets_on_billable_metric_id  (billable_metric_id)
#  index_wallet_targets_on_organization_id     (organization_id)
#  index_wallet_targets_on_wallet_id           (wallet_id)
#
# Foreign Keys
#
#  fk_rails_...  (billable_metric_id => billable_metrics.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (wallet_id => wallets.id)
#
