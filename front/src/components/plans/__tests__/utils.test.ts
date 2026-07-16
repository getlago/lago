import { RefObject } from 'react'

import { RemoveChargeWarningDialogRef } from '~/components/plans/RemoveChargeWarningDialog'
import {
  buildChargeHoverActions,
  getFormattedChargeSelectorSubtitle,
  returnFirstDefinedArrayRatesSumAsString,
  transformFilterObjectToString,
} from '~/components/plans/utils'
import { ALL_FILTER_VALUES, AnyChargeModel } from '~/core/constants/form'

describe('utils', () => {
  describe('transformFilterObjectToString', () => {
    it('should return a string with the filter object keys and no values', () => {
      const filter = {
        key: 'key',
      }
      const result = transformFilterObjectToString(filter.key)

      expect(result).toBe(`{ "${filter.key}": "${ALL_FILTER_VALUES}" }`)
    })

    it('should return a string with the filter object keys and value', () => {
      const filter = {
        key: 'key',
        value: 'value',
      }
      const result = transformFilterObjectToString(filter.key, filter.value)

      expect(result).toBe(`{ "${filter.key}": "${filter.value}" }`)
    })
  })

  describe('returnFirstDefinedArrayRatesSumAsString', () => {
    describe('when arr1 has items', () => {
      it('should return the sum of arr1 rates as a string with single item', () => {
        const arr1 = [{ rate: 5 }]
        const result = returnFirstDefinedArrayRatesSumAsString(arr1)

        expect(result).toBe('5')
      })

      it('should return the sum of arr1 rates as a string with multiple items', () => {
        const arr1 = [{ rate: 5 }, { rate: 10 }, { rate: 15 }]
        const result = returnFirstDefinedArrayRatesSumAsString(arr1)

        expect(result).toBe('30')
      })

      it('should return the sum of arr1 rates when arr2 also has items', () => {
        const arr1 = [{ rate: 5 }, { rate: 10 }]
        const arr2 = [{ rate: 100 }, { rate: 200 }]
        const result = returnFirstDefinedArrayRatesSumAsString(arr1, arr2)

        expect(result).toBe('15')
      })

      it('should handle decimal rates', () => {
        const arr1 = [{ rate: 5.5 }, { rate: 10.25 }, { rate: 3.75 }]
        const result = returnFirstDefinedArrayRatesSumAsString(arr1)

        expect(result).toBe('19.5')
      })

      it('should handle zero rates', () => {
        const arr1 = [{ rate: 0 }, { rate: 0 }]
        const result = returnFirstDefinedArrayRatesSumAsString(arr1)

        expect(result).toBe('0')
      })

      it('should handle negative rates', () => {
        const arr1 = [{ rate: 10 }, { rate: -5 }]
        const result = returnFirstDefinedArrayRatesSumAsString(arr1)

        expect(result).toBe('5')
      })
    })

    describe('when arr1 is empty', () => {
      it('should return the sum of arr2 rates as a string when arr2 has items', () => {
        const arr1: Array<{ rate: number }> = []
        const arr2 = [{ rate: 20 }, { rate: 30 }]
        const result = returnFirstDefinedArrayRatesSumAsString(arr1, arr2)

        expect(result).toBe('50')
      })

      it('should return undefined when arr2 is also empty', () => {
        const arr1: Array<{ rate: number }> = []
        const arr2: Array<{ rate: number }> = []
        const result = returnFirstDefinedArrayRatesSumAsString(arr1, arr2)

        expect(result).toBeUndefined()
      })

      it('should return undefined when arr2 is not provided', () => {
        const arr1: Array<{ rate: number }> = []
        const result = returnFirstDefinedArrayRatesSumAsString(arr1)

        expect(result).toBeUndefined()
      })

      it('should return undefined when arr2 is explicitly undefined', () => {
        const arr1: Array<{ rate: number }> = []
        const result = returnFirstDefinedArrayRatesSumAsString(arr1, undefined)

        expect(result).toBeUndefined()
      })
    })
  })

  describe('getFormattedChargeSelectorSubtitle', () => {
    const translate = (key: string) => key

    it('should return charge model and code joined by bullet', () => {
      const result = getFormattedChargeSelectorSubtitle({
        chargeModel: 'standard' as AnyChargeModel,
        code: 'my_code',
        translate,
      })

      expect(result).toBe('text_65201b8216455901fe273dd6 • my_code')
    })

    it('should return only the charge model translation when code is empty', () => {
      const result = getFormattedChargeSelectorSubtitle({
        chargeModel: 'graduated' as AnyChargeModel,
        code: '',
        translate,
      })

      expect(result).toBe('text_65201b8216455901fe273e11')
    })

    it('should return only the code when translate returns empty string', () => {
      const result = getFormattedChargeSelectorSubtitle({
        chargeModel: 'standard' as AnyChargeModel,
        code: 'my_code',
        translate: () => '',
      })

      expect(result).toBe('my_code')
    })
  })

  describe('buildChargeHoverActions', () => {
    const translate = (key: string) => key
    const buildDialogRef = (): {
      ref: RefObject<RemoveChargeWarningDialogRef>
      openDialog: jest.Mock
    } => {
      const openDialog = jest.fn()
      const ref = {
        current: { openDialog },
      } as unknown as RefObject<RemoveChargeWarningDialogRef>

      return { ref, openDialog }
    }
    const buildEvent = () =>
      ({
        stopPropagation: jest.fn(),
        preventDefault: jest.fn(),
      }) as unknown as React.MouseEvent

    it('returns only the edit action when showDelete is false', () => {
      const onEdit = jest.fn()
      const onDelete = jest.fn()
      const { ref } = buildDialogRef()

      const actions = buildChargeHoverActions({
        showDelete: false,
        showWarningOnDelete: false,
        onDelete,
        onEdit,
        removeChargeWarningDialogRef: ref,
        translate,
      })

      expect(actions).toHaveLength(1)
      expect(actions[0].icon).toBe('pen')
      actions[0].onClick(buildEvent())
      expect(onEdit).toHaveBeenCalledTimes(1)
      expect(onDelete).not.toHaveBeenCalled()
    })

    it('returns trash and edit actions when showDelete is true', () => {
      const { ref } = buildDialogRef()

      const actions = buildChargeHoverActions({
        showDelete: true,
        showWarningOnDelete: false,
        onDelete: jest.fn(),
        onEdit: jest.fn(),
        removeChargeWarningDialogRef: ref,
        translate,
      })

      expect(actions).toHaveLength(2)
      expect(actions[0].icon).toBe('trash')
      expect(actions[1].icon).toBe('pen')
    })

    it('calls onDelete directly when showWarningOnDelete is false', () => {
      const onDelete = jest.fn()
      const { ref, openDialog } = buildDialogRef()

      const actions = buildChargeHoverActions({
        showDelete: true,
        showWarningOnDelete: false,
        onDelete,
        onEdit: jest.fn(),
        removeChargeWarningDialogRef: ref,
        translate,
      })

      const event = buildEvent()

      actions[0].onClick(event)

      expect(event.stopPropagation).toHaveBeenCalledTimes(1)
      expect(event.preventDefault).toHaveBeenCalledTimes(1)
      expect(onDelete).toHaveBeenCalledTimes(1)
      expect(openDialog).not.toHaveBeenCalled()
    })

    it('opens the warning dialog when showWarningOnDelete is true', () => {
      const onDelete = jest.fn()
      const { ref, openDialog } = buildDialogRef()

      const actions = buildChargeHoverActions({
        showDelete: true,
        showWarningOnDelete: true,
        onDelete,
        onEdit: jest.fn(),
        removeChargeWarningDialogRef: ref,
        translate,
      })

      actions[0].onClick(buildEvent())

      expect(openDialog).toHaveBeenCalledTimes(1)
      expect(openDialog).toHaveBeenCalledWith({ callback: onDelete })
      expect(onDelete).not.toHaveBeenCalled()
    })

    it('does not throw when the dialog ref is not yet attached', () => {
      const ref = { current: null } as RefObject<RemoveChargeWarningDialogRef>

      const actions = buildChargeHoverActions({
        showDelete: true,
        showWarningOnDelete: true,
        onDelete: jest.fn(),
        onEdit: jest.fn(),
        removeChargeWarningDialogRef: ref,
        translate,
      })

      expect(() => actions[0].onClick(buildEvent())).not.toThrow()
    })
  })
})
