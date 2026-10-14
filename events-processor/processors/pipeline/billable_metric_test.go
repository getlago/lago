package pipeline

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

func TestEvaluateExpression(t *testing.T) {
	bm := models.BillableMetric{}
	event := models.EnrichedEvent{Timestamp: 1741007009.0, Code: "foo"}
	var result utils.Result[bool]

	t.Run("Without expression", func(t *testing.T) {
		result = evaluateExpression(&event, &bm)
		assert.True(t, result.Success(), "It should succeed when Billable metric does not have a custom expression")
	})

	t.Run("With an expression but without required fields", func(t *testing.T) {
		bm.Expression = "round(event.properties.value * event.properties.units)"
		bm.FieldName = "total_value"
		result = evaluateExpression(&event, &bm)
		assert.False(t, result.Success())
		assert.Contains(
			t,
			result.ErrorMsg(),
			"failed to evaluate expr:",
			"It should fail when the event does not hold the required fields",
		)
	})

	t.Run("With an expression and with required fields", func(t *testing.T) {
		properties := map[string]any{
			"value": "12.0",
			"units": 3,
		}
		event.Properties = properties
		result = evaluateExpression(&event, &bm)
		assert.True(t, result.Success())
		assert.Equal(t, "36", event.Properties["total_value"])
	})

	t.Run("With a float timestamp", func(t *testing.T) {
		event.Timestamp = 1741007009.123

		result = evaluateExpression(&event, &bm)
		assert.True(t, result.Success())
		assert.Equal(t, "36", event.Properties["total_value"])
	})
}
