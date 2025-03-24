package database

import (
	"context"
	"fmt"
	"net"
	"os"
	"testing"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/stretchr/testify/assert"
	"gorm.io/gorm"
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

func TestIsTransientError(t *testing.T) {
	assert.False(t, IsTransientError(nil))
	assert.False(t, IsTransientError(pgx.ErrNoRows))
	assert.False(t, IsTransientError(gorm.ErrRecordNotFound))

	assert.True(t, IsTransientError(net.ErrClosed))
	assert.True(t, IsTransientError(context.DeadlineExceeded))
	assert.True(t, IsTransientError(context.Canceled))

	connError := &pgconn.PgError{
		Code:     "40001",
		Message:  "terminating connection due to conflict with recovery",
		Severity: "FATAL",
	}
	assert.True(t, IsTransientError(connError))

	connError.Code = "42830"
	connError.Message = "invalid_foreign_key"
	assert.False(t, IsTransientError(connError))

	assert.True(t, IsTransientError(fmt.Errorf("eof")))
}
