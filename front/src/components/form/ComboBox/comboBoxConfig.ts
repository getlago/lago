/**
 * Centralized configuration for ComboBox and MultipleComboBox sizing
 * This provides consistent height calculations and can be easily tested
 */

export const COMBOBOX_CONFIG = {
  // Base heights
  ITEM_HEIGHT: 56,
  GROUP_HEADER_HEIGHT: 44,

  // Max visible items before scrolling
  MAX_VISIBLE_ITEMS: 5,

  // Margins and spacing (Item Groups pattern)
  // Item Groups have 8px margin top/bottom (my-2)
  // Items within groups have 4px gap between them (gap-1)
  ITEM_GROUP_MARGIN_TOP: 8,
  ITEM_GROUP_MARGIN_BOTTOM: 8,
  GAP_BETWEEN_ITEMS: 4,
  LIST_PADDING: 4,

  /**
   * Calculate the max height for the listbox
   * Uses MUI's slotProps.listbox maxHeight
   * Formula for 5 items in one group: 8 + (5 × 56) + (4 × 4) + 8 = 312px
   */
  getListboxMaxHeight(): number {
    return (
      this.ITEM_GROUP_MARGIN_TOP +
      this.MAX_VISIBLE_ITEMS * this.ITEM_HEIGHT +
      (this.MAX_VISIBLE_ITEMS - 1) * this.GAP_BETWEEN_ITEMS +
      this.ITEM_GROUP_MARGIN_BOTTOM
    )
  },
} as const
