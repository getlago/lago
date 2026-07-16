import { forwardRef } from 'react'

import { SuggestionList, type SuggestionListRef } from '../common/SuggestionList'
import type { SlashCommandItem } from '../extensions/SlashCommands'

export const SLASH_MENU_CONTAINER_TEST_ID = 'slash-menu-container'
export const SLASH_MENU_ITEM_TEST_ID = 'slash-menu-item'

export type SlashMenuRef = SuggestionListRef

interface SlashMenuProps {
  items: SlashCommandItem[]
  command: (item: SlashCommandItem) => void
}

export const SlashMenu = forwardRef<SlashMenuRef, SlashMenuProps>(({ items, command }, ref) => (
  <SuggestionList
    ref={ref}
    items={items}
    command={command}
    getKey={(item) => item.title}
    getLabel={(item) => item.title}
    getDisabled={(item) => !!item.disabled}
    containerTestId={SLASH_MENU_CONTAINER_TEST_ID}
    itemTestId={SLASH_MENU_ITEM_TEST_ID}
  />
))

SlashMenu.displayName = 'SlashMenu'
