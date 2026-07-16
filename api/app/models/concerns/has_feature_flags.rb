# frozen_string_literal: true

module HasFeatureFlags
  extend ActiveSupport::Concern

  def feature_flag_enabled?(flag)
    flag = flag.to_s
    FeatureFlag.validate!(flag)

    return false unless FeatureFlag.valid?(flag)

    feature_flags.include?(flag)
  end

  def feature_flag_disabled?(flag)
    flag = flag.to_s
    !feature_flag_enabled?(flag)
  end

  def enable_feature_flag!(flag)
    flag = flag.to_s
    FeatureFlag.validate!(flag)

    return unless FeatureFlag.valid?(flag)

    update!(feature_flags: feature_flags | [flag])
  end

  def disable_feature_flag!(flag)
    flag = flag.to_s
    FeatureFlag.validate!(flag)

    return unless FeatureFlag.valid?(flag)

    update!(feature_flags: feature_flags - [flag])
  end
end
