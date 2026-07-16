import { forwardRef } from 'react'

import { SuggestionList, type SuggestionListRef } from '../common/SuggestionList'

export const MENTION_LIST_CONTAINER_TEST_ID = 'mention-list-container'
export const MENTION_LIST_ITEM_TEST_ID = 'mention-list-item'

export interface MentionItem {
  id: string
  label: string
}

export type MentionListRef = SuggestionListRef

interface MentionListProps {
  items: MentionItem[]
  command: (item: MentionItem) => void
}

export const MentionList = forwardRef<MentionListRef, MentionListProps>(
  ({ items, command }, ref) => (
    <SuggestionList
      ref={ref}
      items={items}
      command={command}
      getKey={(item) => item.id}
      getLabel={(item) => item.label}
      containerTestId={MENTION_LIST_CONTAINER_TEST_ID}
      itemTestId={MENTION_LIST_ITEM_TEST_ID}
    />
  ),
)

MentionList.displayName = 'MentionList'
