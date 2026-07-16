# frozen_string_literal: true

module Metadata
  class ItemMetadata < ApplicationRecord
    MAX_NUMBER_OF_KEYS = 50
    MAX_KEY_LENGTH = 100
    MAX_VALUE_LENGTH = 255

    belongs_to :organization
    belongs_to :owner, polymorphic: true

    validates :value, exclusion: {in: [nil], message: :blank}
    validate :value_correctness

    private

    def value_correctness
      return if value.blank?

      unless value.is_a?(Hash)
        errors.add(:value, "must be a Hash")
        return
      end

      if value.size > MAX_NUMBER_OF_KEYS
        errors.add(:value, "cannot have more than #{MAX_NUMBER_OF_KEYS} keys")
      end

      value.each do |key, val|
        unless key.is_a?(String) && key.length <= MAX_KEY_LENGTH
          errors.add(:value, "key '#{key}' must be a String up to #{MAX_KEY_LENGTH} characters")
        end

        valid_value = val.nil? || (val.is_a?(String) && val.length <= MAX_VALUE_LENGTH)
        unless valid_value
          errors.add(:value, "value for key '#{key}' must be empty or a String up to #{MAX_VALUE_LENGTH} characters")
        end
      end
    end
  end
end

# == Schema Information
#
# Table name: item_metadata
# Database name: primary
#
#  id                                             :uuid             not null, primary key
#  owner_type(Polymorphic owner type)             :string           not null
#  value(item_metadata key-value pairs)           :jsonb            not null
#  created_at                                     :datetime         not null
#  updated_at                                     :datetime         not null
#  organization_id(Reference to the organization) :uuid             not null
#  owner_id(Polymorphic owner id)                 :uuid             not null
#
# Indexes
#
#  index_item_metadata_on_organization_id          (organization_id)
#  index_item_metadata_on_owner_type_and_owner_id  (owner_type,owner_id) UNIQUE
#  index_item_metadata_on_value                    (value) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id) ON DELETE => cascade
#
