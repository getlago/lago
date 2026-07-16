# frozen_string_literal: true

module LifetimeUsages
  class FlagRefreshFromPlanUpdateJob < ApplicationJob
    queue_as :default

    def perform(plan)
      LifetimeUsages::FlagRefreshFromPlanUpdateService.call(plan:)
    end
  end
end
