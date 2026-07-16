import { countryDataForCombobox } from '~/core/formats/countryDataForCombobox'

describe('Core > format', () => {
  describe('countryDataForCombobox()', () => {
    it('should retirn a list of element to be displayed in a combobox', () => {
      expect(countryDataForCombobox[0]).toStrictEqual({ label: 'Andorra', value: 'AD' })
    })
  })
})
