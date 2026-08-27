package tests

import "context"

type MockFlagStore struct {
	Key            string
	ExecutionCount int
	ReturnedError  error
}

func (mfs *MockFlagStore) Flag(_ context.Context, key string) error {
	mfs.ExecutionCount++
	mfs.Key = key

	return mfs.ReturnedError
}
