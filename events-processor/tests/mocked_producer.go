package tests

import (
	"context"

	"github.com/getlago/lago/events-processor/config/kafka"
)

type MockMessageProducer struct {
	Key            []byte
	Value          []byte
	ExecutionCount int
	// Fail makes every push fail.
	Fail bool
}

func (mp *MockMessageProducer) Produce(ctx context.Context, msg *kafka.ProducerMessage) bool {
	mp.Key = msg.Key
	mp.Value = msg.Value
	mp.ExecutionCount++

	return !mp.Fail
}

func (mp *MockMessageProducer) GetTopic() string {
	return "mocked_topic"
}
