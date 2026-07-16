/**
 * Scrolls to and expands an accordion element if it's collapsed
 * @param accordionId - The ID of the accordion element to scroll to and expand
 * @param delay - Delay in milliseconds before executing the action (default: 100)
 */
export const scrollToAndExpandAccordion = (accordionId: string, delay: number = 100): void => {
  setTimeout(() => {
    // Make sure the accordion is visible
    const accordion = document.getElementById(accordionId)

    if (!!accordion) {
      accordion.scrollIntoView({ behavior: 'smooth', block: 'start' })

      // Find the AccordionSummary element (which is the clickable part)
      const accordionSummary = accordion.querySelector('[role="button"]') as HTMLElement | null

      if (accordionSummary?.getAttribute('aria-expanded') === 'false') {
        // Use native click method to ensure proper event handling
        accordionSummary.click()
      }
    }
  }, delay)
}

// Hands the Collapse transition back to MUI a little after the open has committed.
const RESTORE_COLLAPSE_ANIM_DELAY_MS = 400
// Frame cap (~500ms at 60fps) so the settle wait can never loop forever.
const SCROLL_SETTLE_MAX_FRAMES = 30

// Nearest scrollable ancestor (the element a scroll actually moves), or the document.
const getScrollParent = (element: HTMLElement): HTMLElement => {
  let node = element.parentElement

  while (node) {
    const { overflowY } = window.getComputedStyle(node)

    if ((overflowY === 'auto' || overflowY === 'scroll') && node.scrollHeight > node.clientHeight) {
      return node
    }

    node = node.parentElement
  }

  return (document.scrollingElement as HTMLElement | null) ?? document.documentElement
}

/**
 * Opens a target accordion (if collapsed), then scrolls it to the top of the scroll
 * container (respecting its `scroll-margin-top`) and focuses it.
 *
 * `behavior` defaults to `'smooth'`. Pass `'auto'` (instant) when the scroll path crosses
 * a VIRTUALIZED list (the usage-charge list on large plans): a smooth scroll animates over
 * many frames, and during those frames the virtualizer re-measures rows and issues its own
 * scroll adjustments that interrupt and derail the animation - it can land mid-list or snap
 * to the top. An instant scroll lands in a single frame, leaving no window to interrupt.
 * Small (non-virtualized) plans keep the smooth scroll.
 *
 * To keep the scroll snappy AND accurate, the open is made instant entirely from here —
 * no CSS class / theme rule (MUI rewrites the accordion's className on the open re-render,
 * which wipes any class added there):
 * - `content-visibility: visible` (inline, which React doesn't manage) forces the card to
 *   render NOW — it may be off-screen under `content-visibility: auto`, which would defer
 *   its render and open height until it scrolls into view.
 * - `transition: none` is set inline on the `.MuiCollapse-root` every frame during the
 *   open, so it can't animate (re-asserting each frame beats whatever MUI writes). The
 *   height therefore lands in ~2 frames instead of animating ~300ms.
 * We still wait for `scrollHeight` to settle (MUI applies the Collapse height in an
 * effect) before the single scroll — but it settles almost immediately now. Both inline
 * styles are handed back after the scroll so user-driven toggles animate normally.
 *
 * Targets that aren't accordions (e.g. a plain `<section>`) have no `[role="button"]`
 * summary, so this degrades to a plain smooth scroll (settles immediately).
 *
 * @param id - The id of the element to scroll to and (when it's an accordion) open
 * @param behavior - Scroll behavior; `'smooth'` (default) or `'auto'` (instant)
 */
export const openAccordionThenScrollTo = (
  id: string,
  behavior: ScrollBehavior = 'smooth',
): void => {
  const target = document.getElementById(id)

  if (!target) return

  const summary = target.querySelector('[role="button"]') as HTMLElement | null
  const willOpen = summary?.getAttribute('aria-expanded') === 'false'
  const accordionRoot = (summary?.closest('.MuiAccordion-root') as HTMLElement | null) ?? target
  const previousContentVisibility = accordionRoot.style.contentVisibility

  // Render the card immediately (overrides the `content-visibility: auto` class) so its
  // open height is laid out now rather than deferred until it scrolls into view.
  accordionRoot.style.contentVisibility = 'visible'

  if (willOpen) summary?.click()

  const suppressCollapseAnimation = (): void => {
    if (!willOpen) return

    const collapse = target.querySelector('.MuiCollapse-root') as HTMLElement | null

    if (collapse) collapse.style.transition = 'none'
  }

  const restore = (): void => {
    accordionRoot.style.contentVisibility = previousContentVisibility

    const collapse = target.querySelector('.MuiCollapse-root') as HTMLElement | null

    if (collapse) collapse.style.transition = ''
  }

  const container = getScrollParent(target)
  let previousScrollHeight = -1
  let stableFrames = 0
  let elapsedFrames = 0

  const scrollWhenSettled = (): void => {
    // Re-assert no-animation every frame: at paint time the Collapse always reads
    // `transition: none`, so it jumps to its open height instead of animating.
    suppressCollapseAnimation()

    const { scrollHeight } = container

    if (scrollHeight === previousScrollHeight) {
      stableFrames += 1
    } else {
      stableFrames = 0
      previousScrollHeight = scrollHeight
    }

    elapsedFrames += 1

    // Scroll once the opened height is in place (height stable) or the cap is hit.
    if (stableFrames >= 2 || elapsedFrames >= SCROLL_SETTLE_MAX_FRAMES) {
      // Caller picks the behavior: instant when crossing a virtualized list (a smooth
      // animation gets derailed by the list's own scroll adjustments), smooth otherwise.
      target.scrollIntoView({ behavior, block: 'start' })
      // preventScroll so the focus doesn't fight the scroll; focusVisible forces the
      // existing `focus-visible:ring` to show on this programmatic focus.
      summary?.focus({ preventScroll: true, focusVisible: true })
      // Hand the inline styles back after the scroll so user toggles animate again.
      setTimeout(restore, RESTORE_COLLAPSE_ANIM_DELAY_MS)

      return
    }

    requestAnimationFrame(scrollWhenSettled)
  }

  requestAnimationFrame(scrollWhenSettled)
}

/**
 * Scrolls to and clicks an element
 * @param selector - The selector of the element to scroll to and click
 * @param delay - Delay in milliseconds before executing the action (default: 0)
 * @param callback - Callback function to execute after the element is clicked
 */
export const scrollToAndClickElement = ({
  selector,
  delay = 0,
  callback,
}: {
  selector: string
  delay?: number
  callback?: () => void
}) => {
  setTimeout(() => {
    const element = document.querySelector(selector) as HTMLElement

    if (!element) return

    element.scrollIntoView({ behavior: 'smooth', block: 'center' })
    element.click()

    callback?.()
  }, delay)
}

/**
 * Scrolls to the top of the element, defaulting to app wrapper
 * @param selector - The selector of the element to scroll to (default: '[data-app-wrapper]')
 */
export const scrollToTop = (selector?: string) => {
  const element = document.querySelector(selector || '[data-app-wrapper]')

  if (!element) return

  setTimeout(() => {
    element.scrollTo({ top: 0, behavior: 'smooth' })
  }, 0)
}
