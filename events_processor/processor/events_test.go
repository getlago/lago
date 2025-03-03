package processor

import (
	"testing"

	"github.com/getlago/lago/events-processor/database"
	"github.com/getlago/lago/events-processor/processor/models"
	"github.com/stretchr/testify/assert"
)

func TestEvaluateExpression(t *testing.T) {
	bm := database.BillableMetric{}
	event := models.Event{}

	// Without expression
	result := evaluateExpression(&event, &bm)
	assert.True(t, result.Success(), "It should succeed when Billable metric does not have a custom expression")

	// With an expression but witout required fields
	bm.Expression = "round(event.properties.value * event.properties.units)"
	bm.FieldName = "value"
	result = evaluateExpression(&event, &bm)
	assert.False(t, result.Success())
	assert.Contains(
		t,
		result.ErrorMsg(),
		"Failed to evaluate expr:",
		"It should fail when the event does not hold the required fields",
	)

	// With an expression and with required fields
	properties := map[string]any{
		"value": 12,
		"units": 3,
	}
	event.Properties = properties
	result = evaluateExpression(&event, &bm)
	assert.True(t, result.Success())
	assert.Equal(t, "36", event.Properties["value"])
}
