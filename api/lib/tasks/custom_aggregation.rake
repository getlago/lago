# frozen_string_literal: true

namespace :custom_aggregation do
  desc "Sandbox for to perform custom aggregation"
  task debug: :environment do
    # Custom aggregator
    def aggregate(event, previous_state, aggregation_properties)
      # TODO: change me
      {total_units: BigDecimal("0"), amount: BigDecimal("0")}
    end

    # Aggregation properties - TODO: change me
    aggregation_properties = {}
    # Intial state
    previous_state = {total_units: BigDecimal("0"), amount: BigDecimal("0")}
    # Event list - TODO: change me
    events = [OpenStruct.new(properties: {})]

    amount = 0

    events.each do |event|
      puts "============="
      puts "Event: #{event}"
      previous_state = aggregate(event, previous_state, aggregation_properties)
      puts "State: #{previous_state}"
      amount += previous_state[:amount]
      puts "Amount: #{amount}"
    end

    puts "============="
    puts "Final state: #{previous_state}"
    puts "Final amount: #{amount}"
  end
end
