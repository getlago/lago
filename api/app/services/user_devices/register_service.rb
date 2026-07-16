# frozen_string_literal: true

module UserDevices
  class RegisterService < BaseService
    Result = BaseResult

    # @option user [User] the user to match the device for
    # @option skip_log [Boolean] whether to skip logging of new device (default: false)
    def initialize(user:, skip_log: false)
      @user = user
      @skip_log = skip_log
      super
    end

    def call
      device_info = CurrentContext.device_info
      return result unless device_info

      fingerprint = Digest::SHA256.hexdigest(device_info[:user_agent])
      device = user.user_devices.find_or_initialize_by(fingerprint:)
      @skip_log ||= !device.new_record?
      device.update!(
        browser: device_info[:browser],
        os: device_info[:os],
        device_type: device_info[:device_type],
        last_logged_at: Time.current,
        last_ip_address: device_info[:ip_address]
      )
      register_security_logs unless skip_log

      result
    end

    private

    attr_reader :user, :skip_log

    def register_security_logs
      user.active_organizations.select(&:security_logs_enabled?).each do |organization|
        Utils::SecurityLog.produce(
          organization:,
          log_type: "user",
          log_event: "user.new_device_logged_in",
          user:
        )
      end
    end
  end
end
