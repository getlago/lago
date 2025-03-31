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
