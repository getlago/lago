package tests

import "github.com/getlago/lago/events-processor/utils"

type MockCacheStore struct {
	LastKey        string
	ExecutionCount int
	ReturnedResult utils.Result[bool]
}

func (mcs *MockCacheStore) Close() error {
	return nil
}

func (mcs *MockCacheStore) ExpireKey(key string) utils.Result[bool] {
	mcs.LastKey = key
	mcs.ExecutionCount++

	return mcs.ReturnedResult
}
