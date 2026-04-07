package utils

import (
	"bytes"
	"context"
	"log/slog"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestLevelHandler_Enabled(t *testing.T) {
	t.Run("Filters below LevelHandler threshold", func(t *testing.T) {
		inner := slog.NewJSONHandler(&bytes.Buffer{}, &slog.HandlerOptions{Level: slog.LevelDebug})
		handler := NewLevelHandler(slog.LevelInfo, inner)

		assert.False(t, handler.Enabled(context.Background(), slog.LevelDebug))
		assert.True(t, handler.Enabled(context.Background(), slog.LevelInfo))
		assert.True(t, handler.Enabled(context.Background(), slog.LevelWarn))
		assert.True(t, handler.Enabled(context.Background(), slog.LevelError))
	})

	t.Run("Respects inner handler threshold", func(t *testing.T) {
		inner := slog.NewJSONHandler(&bytes.Buffer{}, &slog.HandlerOptions{Level: slog.LevelError})
		handler := NewLevelHandler(slog.LevelInfo, inner)

		assert.False(t, handler.Enabled(context.Background(), slog.LevelInfo))
		assert.False(t, handler.Enabled(context.Background(), slog.LevelWarn))
		assert.True(t, handler.Enabled(context.Background(), slog.LevelError))
	})
}

func TestLevelHandler_Handle(t *testing.T) {
	var buf bytes.Buffer
	inner := slog.NewJSONHandler(&buf, &slog.HandlerOptions{Level: slog.LevelDebug})
	logger := slog.New(NewLevelHandler(slog.LevelInfo, inner))

	logger.Debug("should be filtered")
	assert.Empty(t, buf.String())

	logger.Info("should pass")
	assert.Contains(t, buf.String(), "should pass")
}

func TestLevelHandler_WithAttrs(t *testing.T) {
	var buf bytes.Buffer
	inner := slog.NewJSONHandler(&buf, &slog.HandlerOptions{Level: slog.LevelDebug})
	logger := slog.New(NewLevelHandler(slog.LevelInfo, inner)).With("component", "kafka")

	logger.Debug("should be filtered")
	assert.Empty(t, buf.String())

	logger.Info("should pass")
	assert.Contains(t, buf.String(), "should pass")
	assert.Contains(t, buf.String(), "kafka")
}

func TestLevelHandler_WithGroup(t *testing.T) {
	var buf bytes.Buffer
	inner := slog.NewJSONHandler(&buf, &slog.HandlerOptions{Level: slog.LevelDebug})
	logger := slog.New(NewLevelHandler(slog.LevelInfo, inner)).WithGroup("kafka")

	logger.Debug("should be filtered")
	assert.Empty(t, buf.String())

	logger.Info("should pass", "key", "value")
	assert.Contains(t, buf.String(), "should pass")
	assert.Contains(t, buf.String(), "kafka")
}
