import getPropertyShape from '~/core/serializers/getPropertyShape'
import { Properties } from '~/generated/graphql'

describe('getPropertyShape', () => {
  describe('presentationGroupKeys', () => {
    it('GIVEN none THEN returns an empty array', () => {
      expect(getPropertyShape({} as Properties).presentationGroupKeys).toEqual([])
    })

    it('GIVEN a truthy displayInInvoice boolean THEN maps it to the "true" string', () => {
      const shape = getPropertyShape({
        presentationGroupKeys: [{ value: 'region', options: { displayInInvoice: true } }],
      } as unknown as Properties)

      expect(shape.presentationGroupKeys).toEqual([
        { value: 'region', options: { displayInInvoice: 'true' } },
      ])
    })

    it('GIVEN a falsy displayInInvoice THEN maps it to the "false" string', () => {
      const shape = getPropertyShape({
        presentationGroupKeys: [{ value: 'region', options: { displayInInvoice: false } }],
      } as unknown as Properties)

      expect(shape.presentationGroupKeys).toEqual([
        { value: 'region', options: { displayInInvoice: 'false' } },
      ])
    })

    it('GIVEN a missing options object THEN defaults displayInInvoice to "false"', () => {
      const shape = getPropertyShape({
        presentationGroupKeys: [{ value: 'region' }],
      } as unknown as Properties)

      expect(shape.presentationGroupKeys).toEqual([
        { value: 'region', options: { displayInInvoice: 'false' } },
      ])
    })
  })
})
