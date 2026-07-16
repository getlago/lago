import { findNearestScrollableAncestor } from '../findNearestScrollableAncestor'

describe('findNearestScrollableAncestor', () => {
  it('returns null for null input', () => {
    expect(findNearestScrollableAncestor(null)).toBeNull()
  })

  it('returns the nearest ancestor with overflow-y auto/scroll', () => {
    const scroller = document.createElement('div')

    scroller.style.overflowY = 'auto'
    const middle = document.createElement('div')
    const leaf = document.createElement('div')

    scroller.appendChild(middle)
    middle.appendChild(leaf)
    document.body.appendChild(scroller)

    // jsdom does not implement layout; stub the computed overflow.
    jest
      .spyOn(window, 'getComputedStyle')
      .mockImplementation(
        (node) => ({ overflowY: node === scroller ? 'auto' : 'visible' }) as CSSStyleDeclaration,
      )

    expect(findNearestScrollableAncestor(leaf)).toBe(scroller)
    document.body.removeChild(scroller)
  })

  it('falls back to document.scrollingElement when no scrollable ancestor exists', () => {
    const leaf = document.createElement('div')

    document.body.appendChild(leaf)
    jest
      .spyOn(window, 'getComputedStyle')
      .mockImplementation(() => ({ overflowY: 'visible' }) as CSSStyleDeclaration)
    expect(findNearestScrollableAncestor(leaf)).toBe(document.scrollingElement)
    document.body.removeChild(leaf)
  })
})
