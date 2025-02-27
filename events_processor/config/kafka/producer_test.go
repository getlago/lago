package kafka

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestNewProducer(t *testing.T) {
	cfg := &ProducerConfig{
		Topic: "test-topic",
	}

	producer, err := NewProducer(cfg)

	assert.NoError(t, err)
	assert.NotNil(t, producer)
	assert.Equal(t, cfg.Topic, producer.config.Topic)
}
