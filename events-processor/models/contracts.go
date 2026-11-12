package models

import "github.com/getlago/lago/events-processor/utils"

// advanceRateCardQuery mirrors the API's pay in advance resolver: an active contract,
// a kept contract rate card, an advance rate card on a metered product of the metric.
// Rate cards and products keep their discarded rows, as the API reads them through
// the contract rate card. The API still picks the effective version, the product
// filter and the phase when it bills the event.
const advanceRateCardQuery = `SELECT contract_rate_cards.id
FROM contract_rate_cards
JOIN contracts ON contracts.id = contract_rate_cards.contract_id
JOIN rate_cards ON rate_cards.id = contract_rate_cards.rate_card_id
JOIN products ON products.id = rate_cards.product_id
WHERE contracts.organization_id = ?
	AND contracts.external_id = ?
	AND contracts.status = 'active'
	AND contract_rate_cards.deleted_at IS NULL
	AND rate_cards.billing_timing = 'advance'
	AND products.product_type = 'metered'
	AND products.billable_metric_id = ?
LIMIT 1`

// HasAdvanceRateCard reports whether the active contract has at least one rate card
// billed in advance for the billable metric: the product counterpart of
// HasPayInAdvanceCharge.
func (store *ApiStore) HasAdvanceRateCard(organizationID string, externalContractID string, billableMetricID string) utils.Result[bool] {
	var ids []string

	result := store.db.Connection.Raw(advanceRateCardQuery, organizationID, externalContractID, billableMetricID).Scan(&ids)
	if result.Error != nil {
		return utils.FailedBoolResult(result.Error)
	}

	return utils.SuccessResult(len(ids) > 0)
}
