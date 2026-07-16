import { wrapInBlockWrapper } from '../BlockWrapper'

describe('wrapInBlockWrapper', () => {
  describe('GIVEN a block type name and inner DOMOutputSpec', () => {
    describe('WHEN called with a paragraph inner spec', () => {
      it('THEN should wrap it in spacer > block-wrapper structure', () => {
        const inner = ['p', 0] as const
        const result = wrapInBlockWrapper('paragraph', inner)

        expect(result).toEqual([
          'div',
          { class: 'spacer', 'data-type': 'paragraph' },
          ['div', { class: 'block-wrapper' }, inner],
        ])
      })
    })

    describe('WHEN called with a heading inner spec', () => {
      it('THEN should set the correct data-type attribute', () => {
        const inner = ['h1', 0] as const
        const result = wrapInBlockWrapper('heading-1', inner)

        const outerAttrs = (result as unknown as unknown[])[1] as Record<string, string>

        expect(outerAttrs['data-type']).toBe('heading-1')
        expect(outerAttrs.class).toBe('spacer')
      })
    })

    describe('WHEN called with a complex inner spec', () => {
      it('THEN should nest it correctly inside block-wrapper', () => {
        const inner = ['pre', ['code', 0]] as const
        const result = wrapInBlockWrapper('codeBlock', inner)

        const blockWrapper = (result as unknown as unknown[])[2] as unknown[]

        expect(blockWrapper[0]).toBe('div')
        expect((blockWrapper[1] as Record<string, string>).class).toBe('block-wrapper')
        expect(blockWrapper[2]).toEqual(inner)
      })
    })
  })
})
