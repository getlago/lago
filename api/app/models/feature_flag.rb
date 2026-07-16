# frozen_string_literal: true

class FeatureFlag
  DEFINITION = begin
    yaml = YAML.parse_file(Rails.root.join("app/config/feature_flags.yaml"))
    yaml.presence&.to_ruby || {} # Handle empty yaml file
  end.with_indifferent_access.freeze

  class << self
    def valid?(flag)
      DEFINITION.key?(flag)
    end

    def validate!(flag)
      return if Rails.env.production?

      raise ArgumentError, "Unknown feature flag: #{flag}" unless valid?(flag)
    end

    def sanitize!
      valid_keys = DEFINITION.keys

      Organization.where.not(feature_flags: []).find_each do |organization|
        valid_flags = organization.feature_flags & valid_keys

        organization.update!(feature_flags: valid_flags)
      end
    end
  end
end
