package tests

import (
	"context"
	"sync"

	"github.com/getlago/lago/events-processor/config/kafka"
)

type MockMessageProducer struct {
	Key            []byte
	Value          []byte
	ExecutionCount int
	// Fail makes every push fail.
	Fail bool

	// Guards the fields above for pushes made from a goroutine.
	mu sync.Mutex
}

func (mp *MockMessageProducer) Produce(ctx context.Context, msg *kafka.ProducerMessage) bool {
	mp.mu.Lock()
	defer mp.mu.Unlock()

	mp.Key = msg.Key
	mp.Value = msg.Value
	mp.ExecutionCount++

	return !mp.Fail
}

// Executions returns ExecutionCount, safe to read while a goroutine pushes.
func (mp *MockMessageProducer) Executions() int {
	mp.mu.Lock()
	defer mp.mu.Unlock()

	return mp.ExecutionCount
}

func (mp *MockMessageProducer) GetTopic() string {
	return "mocked_topic"
}
