package database

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestNewConnection(t *testing.T) {
	config := DBConfig{
		Url:      "invalid connection",
		MaxConns: 200,
	}

	_, err := NewConnection(config)
	assert.Error(t, err)

	config.Url = os.Getenv("DATABASE_URL")

	db, err := NewConnection(config)
	assert.NoError(t, err)
	assert.NotNil(t, db)
	assert.NotNil(t, db.Connection)
	assert.NotNil(t, db.logger)
}
