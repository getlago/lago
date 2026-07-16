# frozen_string_literal: true

module KafkaHelper
  extend ActiveSupport::Concern

  included do
    let(:karafka_producer) { instance_double(WaterDrop::Producer) }
    let(:kafka_messages) { [] }
  end

  def stub_karafka_producer
    allow(Karafka).to receive(:producer).and_return(karafka_producer)
    allow(karafka_producer).to receive(:produce_async) { |args| kafka_messages << args }
    allow(karafka_producer).to receive(:produce_many_async) { |args| kafka_messages.concat(args) }
  end
end

RSpec.configure do |config|
  config.include KafkaHelper, :capture_kafka_messages
  config.before(:each, :capture_kafka_messages) { stub_karafka_producer }
end
