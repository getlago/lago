package kafka

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/twmb/franz-go/pkg/kgo"
)

func createRecord(key string, offset int64) *kgo.Record {
	return &kgo.Record{
		Key:    []byte(key),
		Value:  []byte("value"),
		Offset: offset,
	}
}

func TestFindMaxCommitableRecord(t *testing.T) {
	{
		tests := []struct {
			name             string
			processedRecords []*kgo.Record
			records          []*kgo.Record
			expected         *kgo.Record
		}{
			{
				name: "WIth continuous offsets",
				processedRecords: []*kgo.Record{
					createRecord("key1", 1),
					createRecord("key2", 2),
				},
				records: []*kgo.Record{
					createRecord("key1", 1),
					createRecord("key2", 2),
					createRecord("key3", 3),
					createRecord("key4", 4),
				},
				expected: createRecord("key2", 2),
			},
			{
				name: "With non-continuous offsets",
				processedRecords: []*kgo.Record{
					createRecord("key1", 1),
					createRecord("key5", 5),
				},
				records: []*kgo.Record{
					createRecord("key1", 1),
					createRecord("key3", 3),
					createRecord("key5", 5),
					createRecord("key7", 7),
				},
				expected: createRecord("key1", 1),
			},
			{
				name:             "With empty processed records",
				processedRecords: []*kgo.Record{},
				records: []*kgo.Record{
					createRecord("key1", 1),
					createRecord("key3", 3),
					createRecord("key5", 5),
					createRecord("key7", 7),
				},
				expected: nil,
			},
			{
				name: "All records processed",
				processedRecords: []*kgo.Record{
					createRecord("key1", 1),
					createRecord("key2", 2),
					createRecord("key3", 3),
					createRecord("key4", 4),
				},
				records: []*kgo.Record{
					createRecord("key1", 1),
					createRecord("key2", 2),
					createRecord("key3", 3),
					createRecord("key4", 4),
				},
				expected: createRecord("key4", 4),
			},
			{
				name: "Only one processed records - not first",
				processedRecords: []*kgo.Record{
					createRecord("key5", 5),
				},
				records: []*kgo.Record{
					createRecord("key1", 1),
					createRecord("key3", 3),
					createRecord("key5", 5),
					createRecord("key7", 7),
				},
				expected: nil,
			},
			{
				name: "Only one processed records - first",
				processedRecords: []*kgo.Record{
					createRecord("key1", 1),
				},
				records: []*kgo.Record{
					createRecord("key1", 1),
					createRecord("key3", 3),
					createRecord("key5", 5),
					createRecord("key7", 7),
				},
				expected: createRecord("key1", 1),
			},
		}

		for _, test := range tests {
			t.Run(test.name, func(t *testing.T) {
				result := findMaxCommitableRecord(test.processedRecords, test.records)

				if test.expected == nil {
					assert.Nil(t, result)
				} else {
					assert.NotNil(t, result)
					assert.Equal(t, test.expected.Key, result.Key)
					assert.Equal(t, test.expected.Offset, result.Offset)
				}
			})
		}
	}
}
