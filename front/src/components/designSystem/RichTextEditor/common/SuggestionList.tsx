import type { SuggestionKeyDownProps } from '@tiptap/suggestion'
import { forwardRef, useCallback, useEffect, useImperativeHandle, useRef, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { MenuPopper } from '~/styles/designSystem/PopperComponents'

import { POPPER_WRAPPER_CLASSES } from '../../Popper'

export const SUGGESTION_LIST_CONTAINER_TEST_ID = 'suggestion-list-container'
export const SUGGESTION_LIST_ITEM_TEST_ID = 'suggestion-list-item'

export interface SuggestionListRef {
  onKeyDown: (props: SuggestionKeyDownProps) => boolean
}

interface SuggestionListProps<T> {
  items: T[]
  command: (item: T) => void
  getKey: (item: T) => string
  getLabel: (item: T) => string
  getDisabled?: (item: T) => boolean
  containerTestId?: string
  itemTestId?: string
}

function SuggestionListInner<T>(
  {
    items,
    command,
    getKey,
    getLabel,
    getDisabled,
    containerTestId = SUGGESTION_LIST_CONTAINER_TEST_ID,
    itemTestId = SUGGESTION_LIST_ITEM_TEST_ID,
  }: SuggestionListProps<T>,
  ref: React.ForwardedRef<SuggestionListRef>,
) {
  const [selectedIndex, setSelectedIndex] = useState(0)
  const itemRefs = useRef<(HTMLButtonElement | null)[]>([])

  useEffect(() => setSelectedIndex(0), [items])

  useEffect(() => {
    itemRefs.current[selectedIndex]?.scrollIntoView({ block: 'nearest' })
  }, [selectedIndex])

  const setItemRef = useCallback(
    (index: number) => (el: HTMLButtonElement | null) => {
      itemRefs.current[index] = el
    },
    [],
  )

  const findNextEnabled = useCallback(
    (from: number, direction: 1 | -1) => {
      let next = (from + direction + items.length) % items.length
      let attempts = 0

      while (getDisabled?.(items[next]) && attempts < items.length) {
        next = (next + direction + items.length) % items.length
        attempts++
      }

      return next
    },
    [items, getDisabled],
  )

  useImperativeHandle(ref, () => ({
    onKeyDown: ({ event }: { event: KeyboardEvent }) => {
      if (event.key === 'ArrowUp') {
        setSelectedIndex((prev) => findNextEnabled(prev, -1))
        return true
      }
      if (event.key === 'ArrowDown') {
        setSelectedIndex((prev) => findNextEnabled(prev, 1))
        return true
      }
      if (event.key === 'Enter') {
        if (getDisabled?.(items[selectedIndex])) return true
        command(items[selectedIndex])
        return true
      }
      return false
    },
  }))

  if (!items.length) return null

  return (
    <div data-test={containerTestId} className={POPPER_WRAPPER_CLASSES}>
      <MenuPopper>
        {items.map((item, index) => (
          <Button
            ref={setItemRef(index)}
            key={getKey(item)}
            data-test={`${itemTestId}-${index}`}
            variant={index === selectedIndex ? 'secondary' : 'quaternary'}
            align="left"
            fullWidth
            disabled={getDisabled?.(item)}
            onClick={() => command(item)}
          >
            <Typography variant="bodyHl" color={getDisabled?.(item) ? 'grey400' : 'grey700'}>
              {getLabel(item)}
            </Typography>
          </Button>
        ))}
      </MenuPopper>
    </div>
  )
}

export const SuggestionList = forwardRef(SuggestionListInner) as <T>(
  props: SuggestionListProps<T> & { ref?: React.Ref<SuggestionListRef> },
) => React.ReactElement | null
