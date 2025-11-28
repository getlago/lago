package models

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestAggregationTypeString(t *testing.T) {
	t.Run("should return the aggregation type", func(t *testing.T) {
		tests := []struct {
			aggregationType int
			expected        string
		}{
			{0, "count"},
			{1, "sum"},
			{2, "max"},
			{3, "unique_count"},
			{5, "weighted_sum"},
			{6, "latest"},
			{7, "custom"},
		}

		for _, test := range tests {
			var bm = BillableMetric{AggregationType: AggregationType(test.aggregationType)}
			assert.Equal(t, test.expected, bm.AggregationType.String())
		}
	})

	t.Run("should return an empty string for invalid aggregation type", func(t *testing.T) {
		var bm = BillableMetric{AggregationType: 99}
		assert.Equal(t, "", bm.AggregationType.String())
	})
}
