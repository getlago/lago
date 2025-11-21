package utils

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestGetEnvAsInt(t *testing.T) {
	t.Run("When environment variable exists", func(t *testing.T) {
		t.Setenv("TEST_INT_ENV", "42")
		value, err := GetEnvAsInt("TEST_INT_ENV", 0)
		assert.Equal(t, 42, value)
		assert.NoError(t, err)
	})

	t.Run("When environment variable does not exist", func(t *testing.T) {
		value, err := GetEnvAsInt("NON_EXISTENT_INT_ENV", 100)
		assert.Equal(t, 100, value)
		assert.NoError(t, err)
	})

	t.Run("When environment variable is invalid", func(t *testing.T) {
		t.Setenv("INVALID_INT_ENV", "not_an_int")
		value, err := GetEnvAsInt("INVALID_INT_ENV", 0)
		assert.Equal(t, 0, value)
		assert.Error(t, err)
	})
}

func TestParseBrokersEnv(t *testing.T) {
	t.Run("should parse comma-separated brokers", func(t *testing.T) {
		brokersStr := "broker1:9092, broker2:9092, broker3:9092"
		result := ParseBrokersEnv(brokersStr)
		assert.Equal(t, []string{"broker1:9092", "broker2:9092", "broker3:9092"}, result)
	})

	t.Run("should parse single broker", func(t *testing.T) {
		brokersStr := "localhost:9092"
		result := ParseBrokersEnv(brokersStr)
		assert.Equal(t, []string{"localhost:9092"}, result)
	})

	t.Run("should return empty slice for empty string", func(t *testing.T) {
		brokersStr := ""
		result := ParseBrokersEnv(brokersStr)
		assert.Equal(t, []string{}, result)
	})
}

func TestGetEnvAsBool(t *testing.T) {
	t.Run("should return true when environment variable is set to 'true'", func(t *testing.T) {
		t.Setenv("TEST_BOOL_ENV", "true")
		value := GetEnvAsBool("TEST_BOOL_ENV", false)
		assert.True(t, value)
	})

	t.Run("should return false when environment variable is set to 'false'", func(t *testing.T) {
		t.Setenv("TEST_BOOL_ENV", "false")
		value := GetEnvAsBool("TEST_BOOL_ENV", true)
		assert.False(t, value)
	})

	t.Run("should return default value when environment variable is not set", func(t *testing.T) {
		value := GetEnvAsBool("NON_EXISTENT_BOOL_ENV", true)
		assert.True(t, value)
	})

	t.Run("should return default value when environment variable is invalid", func(t *testing.T) {
		t.Setenv("INVALID_BOOL_ENV", "not_a_bool")
		value := GetEnvAsBool("INVALID_BOOL_ENV", false)
		assert.False(t, value)
	})
}
