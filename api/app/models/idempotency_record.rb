# frozen_string_literal: true

# # IdempotencyRecord is a low-level model used for tracking idempotent operations.
#
# This class provides the database representation for idempotency tracking,
# but direct usage is discouraged. Instead, use the higher-level API provided
# by the Idempotency class
class IdempotencyRecord < ApplicationRecord
  belongs_to :resource, polymorphic: true, optional: true
  belongs_to :organization, optional: true
end

# == Schema Information
#
# Table name: idempotency_records
# Database name: primary
#
#  id              :uuid             not null, primary key
#  idempotency_key :binary           not null
#  resource_type   :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid
#  resource_id     :uuid
#
# Indexes
#
#  index_idempotency_records_on_idempotency_key                (idempotency_key) UNIQUE
#  index_idempotency_records_on_organization_id                (organization_id)
#  index_idempotency_records_on_resource_type_and_resource_id  (resource_type,resource_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#
