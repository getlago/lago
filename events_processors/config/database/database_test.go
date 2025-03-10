package database

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestNewConnection(t *testing.T) {
	_, err := NewConnection("invalid connection")
	assert.Error(t, err)

	db, err := NewConnection(os.Getenv("DATABASE_URL"))
	assert.NoError(t, err)
	assert.NotNil(t, db)
	assert.NotNil(t, db.Connection)
	assert.NotNil(t, db.logger)
}
