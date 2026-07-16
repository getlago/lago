# frozen_string_literal: true

module UsageMonitoring
  class ProcessWalletAlertsService < BaseService
    Result = BaseResult

    def initialize(wallet:)
      @wallet = wallet
      super
    end

    def call
      return result unless wallet.alerts.any?

      wallet.alerts.using_wallet.includes(:thresholds).find_each do |alert|
        ProcessAlertService.call(alert:, alertable: wallet, current_metrics: wallet)
      end

      result
    end

    private

    attr_reader :wallet
  end
end
