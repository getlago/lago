package tests

import "github.com/getlago/lago/events-processor/utils"

type MockCacheStore struct {
	LastKey        string
	ReturnedResult utils.Result[bool]
}

func (mcs *MockCacheStore) Close() error {
	return nil
}

func (mcs *MockCacheStore) DeleteKey(key string) utils.Result[bool] {
	mcs.LastKey = key

	return mcs.ReturnedResult
}
