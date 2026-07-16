import { useCallback, useEffect, useRef, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { MenuPopper } from '~/styles/designSystem/PopperComponents'

export const LINK_PASTE_POPUP_TEST_ID = 'link-paste-popup'
export const LINK_PASTE_POPUP_URL_TEST_ID = 'link-paste-popup-url'
export const LINK_PASTE_POPUP_CARD_BUTTON_TEST_ID = 'link-paste-popup-card-button'
export const LINK_PASTE_POPUP_TEXT_BUTTON_TEST_ID = 'link-paste-popup-text-button'

interface LinkPastePopupProps {
  url: string
  onDisplayAsCard: () => void
  onKeepAsText: () => void
}

const actions = ['displayAsCard', 'keepAsText'] as const

export const LinkPastePopup = ({ url, onDisplayAsCard, onKeepAsText }: LinkPastePopupProps) => {
  const [selectedIndex, setSelectedIndex] = useState(0)
  const containerRef = useRef<HTMLDivElement>(null)

  const execute = useCallback(
    (index: number) => {
      if (actions[index] === 'displayAsCard') {
        onDisplayAsCard()
      } else {
        onKeepAsText()
      }
    },
    [onDisplayAsCard, onKeepAsText],
  )

  useEffect(() => {
    containerRef.current?.focus()
  }, [])

  useEffect(() => {
    const container = containerRef.current

    if (!container) return

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'ArrowUp') {
        e.preventDefault()
        setSelectedIndex((prev) => (prev - 1 + actions.length) % actions.length)
      } else if (e.key === 'ArrowDown') {
        e.preventDefault()
        setSelectedIndex((prev) => (prev + 1) % actions.length)
      } else if (e.key === 'Enter') {
        e.preventDefault()
        execute(selectedIndex)
      }
    }

    container.addEventListener('keydown', handleKeyDown)

    return () => container.removeEventListener('keydown', handleKeyDown)
  }, [selectedIndex, execute])

  return (
    <div
      ref={containerRef}
      tabIndex={-1}
      data-test={LINK_PASTE_POPUP_TEST_ID}
      className="w-72 overflow-hidden rounded-xl bg-white shadow-md outline-none"
    >
      <MenuPopper>
        <div
          data-test={LINK_PASTE_POPUP_URL_TEST_ID}
          className="border-b border-grey-200 px-3 py-2"
        >
          <Typography variant="captionHl" color="grey600" noWrap>
            {url}
          </Typography>
        </div>
        <Button
          data-test={LINK_PASTE_POPUP_CARD_BUTTON_TEST_ID}
          variant={selectedIndex === 0 ? 'secondary' : 'quaternary'}
          align="left"
          fullWidth
          onClick={onDisplayAsCard}
        >
          <Typography variant="bodyHl" color="grey700">
            Display as card
          </Typography>
        </Button>
        <Button
          data-test={LINK_PASTE_POPUP_TEXT_BUTTON_TEST_ID}
          variant={selectedIndex === 1 ? 'secondary' : 'quaternary'}
          align="left"
          fullWidth
          onClick={onKeepAsText}
        >
          <Typography variant="bodyHl" color="grey700">
            Keep as text
          </Typography>
        </Button>
      </MenuPopper>
    </div>
  )
}
