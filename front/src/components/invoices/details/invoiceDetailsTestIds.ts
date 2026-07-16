/**
 * Standalone test ID constants for invoice-detail components.
 *
 * Defined in a plain `.ts` module (no React/JSX) so Cypress E2E tests can
 * import them directly. Component modules also import from here to keep a
 * single source of truth.
 */

// FeeActionsCell — the 3-dots menu cell rendered for each fee row
export const FEE_ACTIONS_CELL_TEST_ID = 'fee-actions-cell'
export const FEE_ACTIONS_BUTTON_TEST_ID = 'fee-actions-button'
export const FEE_COPY_ID_BUTTON_TEST_ID = 'fee-copy-id-button'
export const FEE_VIEW_DETAILS_BUTTON_TEST_ID = 'fee-view-details-button'

// ViewFeeDetailsDrawer — the read-only fee details drawer
export const VIEW_FEE_DETAILS_DRAWER_TEST_ID = 'view-fee-details-drawer'
export const VIEW_FEE_DETAILS_HEADER_TEST_ID = 'view-fee-details-header'
export const VIEW_FEE_DETAILS_OVERVIEW_TEST_ID = 'view-fee-details-overview'
export const VIEW_FEE_DETAILS_SOURCE_ITEM_TEST_ID = 'view-fee-details-source-item'
export const VIEW_FEE_DETAILS_PGK_TABLE_TEST_ID = 'view-fee-details-pgk-table'

// InvoiceDetailsTableBodyLine — clickable fee row (dynamic id appended)
export const FEE_ROW_TEST_ID_PREFIX = 'fee-row'
