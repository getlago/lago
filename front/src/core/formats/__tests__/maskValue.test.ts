import { maskValue } from '~/core/formats/maskValue'

describe('maskValue', () => {
  describe('GIVEN empty value', () => {
    it('THEN should return dash', () => {
      expect(maskValue('')).toBe('-')
    })
  })

  describe('GIVEN no options', () => {
    it('THEN should prepend 4 dots without space', () => {
      expect(maskValue('4242')).toBe('••••4242')
      expect(maskValue('1234')).toBe('••••1234')
    })
  })

  describe('GIVEN visibleChars option', () => {
    it('THEN should slice value from the end', () => {
      expect(maskValue('11199999-9999-4522-9acd-8659999d9ae8', { visibleChars: 4 })).toBe(
        '••••9ae8',
      )
      expect(maskValue('hello', { visibleChars: 4 })).toBe('••••ello')
      expect(maskValue('abcdefgh', { visibleChars: 2 })).toBe('••••gh')
    })
  })

  describe('GIVEN dotsCount option', () => {
    it('THEN should use custom number of dots', () => {
      expect(maskValue('4242', { dotsCount: 6 })).toBe('••••••4242')
      expect(maskValue('4242', { dotsCount: 2 })).toBe('••4242')
    })
  })

  describe('GIVEN withSpace option', () => {
    it('WHEN true THEN should add space between dots and value', () => {
      expect(maskValue('4242', { withSpace: true })).toBe('•••• 4242')
      expect(maskValue('1234', { withSpace: true, dotsCount: 6 })).toBe('•••••• 1234')
    })

    it('WHEN false THEN should not add space', () => {
      expect(maskValue('4242', { withSpace: false })).toBe('••••4242')
    })
  })

  describe('GIVEN multiple options', () => {
    it('THEN should apply all', () => {
      expect(
        maskValue('11199999-9999-4522-9acd-8659999d9ae8', { visibleChars: 3, dotsCount: 3 }),
      ).toBe('•••ae8')
      expect(maskValue('abcdefgh', { visibleChars: 2, dotsCount: 6, withSpace: true })).toBe(
        '•••••• gh',
      )
    })
  })
})
