package tests

type MockFlagStore struct {
	Key            string
	ExecutionCount int
	ReturnedError  error
}

func (mfs *MockFlagStore) Flag(key string) error {
	mfs.ExecutionCount++
	mfs.Key = key

	return mfs.ReturnedError
}
