# frozen_string_literal: true

class PendingViesCheck < ApplicationRecord
  ERROR_TYPE_MAPPING = {
    Valvat::RateLimitError => "rate_limit",
    Valvat::Timeout => "timeout",
    Valvat::BlockedError => "blocked",
    Valvat::InvalidRequester => "invalid_requester",
    Valvat::ServiceUnavailable => "service_unavailable",
    Valvat::HTTPError => "service_unavailable",
    Valvat::MemberStateUnavailable => "member_state_unavailable"
  }.freeze

  KNOWN_ERROR_TYPES = (ERROR_TYPE_MAPPING.values + ["unknown"]).freeze

  belongs_to :organization
  belongs_to :billing_entity
  belongs_to :customer

  validates :customer_id, uniqueness: true
  validates :attempts_count, numericality: {greater_than_or_equal_to: 0}
  validates :last_error_type, inclusion: {in: KNOWN_ERROR_TYPES}, allow_nil: true

  def self.error_type_for(exception)
    ERROR_TYPE_MAPPING.fetch(exception.class, "unknown")
  end
end

# == Schema Information
#
# Table name: pending_vies_checks
# Database name: primary
#
#  id                        :uuid             not null, primary key
#  attempts_count            :integer          default(0), not null
#  last_attempt_at           :datetime
#  last_error_message        :text
#  last_error_type           :string
#  tax_identification_number :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  billing_entity_id         :uuid             not null
#  customer_id               :uuid             not null
#  organization_id           :uuid             not null
#
# Indexes
#
#  index_pending_vies_checks_on_billing_entity_id  (billing_entity_id)
#  index_pending_vies_checks_on_customer_id        (customer_id) UNIQUE
#  index_pending_vies_checks_on_organization_id    (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (billing_entity_id => billing_entities.id)
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (organization_id => organizations.id)
#
