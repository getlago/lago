package tests

import (
	"context"

	"github.com/getlago/lago/events-processor/config/kafka"
)

type MockMessageProducer struct {
	Key            []byte
	Value          []byte
	ExecutionCount int
}

func (mp *MockMessageProducer) Produce(ctx context.Context, msg *kafka.ProducerMessage) bool {
	mp.Key = msg.Key
	mp.Value = msg.Value
	mp.ExecutionCount++

	return true
}

func (mp *MockMessageProducer) GetTopic() string {
	return "mocked_topic"
}
