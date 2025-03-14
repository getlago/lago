package models

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestPushUnique(t *testing.T) {
	refreshSubs := RefreshedSubscriptions{}

	id := refreshSubs.PushUnique("sub123")
	assert.Equal(t, "sub123", id)
	assert.Len(t, refreshSubs.IDs, 1)
	assert.Contains(t, refreshSubs.IDs, "sub123")

	id = refreshSubs.PushUnique("sub456")
	assert.Equal(t, "sub456", id)
	assert.Len(t, refreshSubs.IDs, 2)
	assert.Contains(t, refreshSubs.IDs, "sub456")

	id = refreshSubs.PushUnique("sub123")
	assert.Equal(t, "sub123", id)
	assert.Len(t, refreshSubs.IDs, 2)
}
