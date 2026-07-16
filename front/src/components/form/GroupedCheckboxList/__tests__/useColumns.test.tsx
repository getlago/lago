import { renderHook } from '@testing-library/react'

import { useColumns } from '../useColumns'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockGroups = {
  customers: {
    id: 'customers',
    label: 'Customers',
    items: [
      { id: 'customer.create', label: 'Create customer' },
      { id: 'customer.update', label: 'Update customer' },
    ],
  },
  invoices: {
    id: 'invoices',
    label: 'Invoices',
    items: [{ id: 'invoice.create', label: 'Create invoice' }],
  },
}

const mockCheckboxValues = {
  'customer.create': true,
  'customer.update': false,
  'invoice.create': true,
}

const defaultParams = {
  isEditable: true,
  checkboxValues: mockCheckboxValues,
  groupingMap: mockGroups,
  overallCheckboxValue: undefined as boolean | undefined,
  onOverallCheckboxChange: jest.fn(),
  onGroupCheckboxClick: jest.fn(),
  AppField: jest.fn(),
}

describe('useColumns', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN editable mode is enabled', () => {
    describe('WHEN rendering columns', () => {
      it('THEN returns 3 columns including checkbox column', () => {
        const { result } = renderHook(() => useColumns(defaultParams))

        expect(result.current).toHaveLength(3)
        expect(result.current.map((col) => col.key)).toEqual(['checkbox', 'label', 'total'])
      })

      it('THEN checkbox column has correct minWidth', () => {
        const { result } = renderHook(() => useColumns(defaultParams))

        const checkboxColumn = result.current.find((col) => col.key === 'checkbox')

        expect(checkboxColumn?.minWidth).toBe(40)
      })
    })
  })

  describe('GIVEN editable mode is disabled', () => {
    describe('WHEN rendering columns', () => {
      it('THEN returns 2 columns without checkbox column', () => {
        const { result } = renderHook(() =>
          useColumns({
            ...defaultParams,
            isEditable: false,
          }),
        )

        expect(result.current).toHaveLength(2)
        expect(result.current.map((col) => col.key)).toEqual(['label', 'total'])
      })
    })
  })

  describe('GIVEN label column configuration', () => {
    describe('WHEN checking column properties', () => {
      it('THEN has correct label translation key', () => {
        const { result } = renderHook(() => useColumns(defaultParams))

        const labelColumn = result.current.find((col) => col.key === 'label')

        expect(labelColumn?.label).toBe('text_1766047828726zeybs9mgzhl')
      })

      it('THEN has correct minWidth', () => {
        const { result } = renderHook(() => useColumns(defaultParams))

        const labelColumn = result.current.find((col) => col.key === 'label')

        expect(labelColumn?.minWidth).toBe(230)
      })

      it('THEN has isFullWidth set to true', () => {
        const { result } = renderHook(() => useColumns(defaultParams))

        const labelColumn = result.current.find((col) => col.key === 'label')

        expect(labelColumn?.isFullWidth).toBe(true)
      })
    })
  })

  describe('GIVEN total column configuration', () => {
    describe('WHEN checking column properties', () => {
      it('THEN has correct label translation key', () => {
        const { result } = renderHook(() => useColumns(defaultParams))

        const totalColumn = result.current.find((col) => col.key === 'total')

        expect(totalColumn?.label).toBe('text_1766047828725ykfgqmtfczr')
      })

      it('THEN has correct minWidth', () => {
        const { result } = renderHook(() => useColumns(defaultParams))

        const totalColumn = result.current.find((col) => col.key === 'total')

        expect(totalColumn?.minWidth).toBe(120)
      })

      it('THEN has right alignment', () => {
        const { result } = renderHook(() => useColumns(defaultParams))

        const totalColumn = result.current.find((col) => col.key === 'total')

        expect(totalColumn?.align).toBe('right')
      })
    })
  })

  describe('GIVEN total column content rendering', () => {
    describe('WHEN row type is group', () => {
      it('THEN returns enabled/total count', () => {
        const { result } = renderHook(() => useColumns(defaultParams))

        const totalColumn = result.current.find((col) => col.key === 'total')
        const content = totalColumn?.content?.(
          { type: 'group', key: 'customers', label: 'Customers' },
          {} as never,
        )

        expect(content).not.toBeNull()
      })
    })

    describe('WHEN row type is line', () => {
      it('THEN returns null', () => {
        const { result } = renderHook(() => useColumns(defaultParams))

        const totalColumn = result.current.find((col) => col.key === 'total')
        const content = totalColumn?.content?.(
          { type: 'line', key: 'customer.create', label: 'Create', groupKey: 'customers' },
          {} as never,
        )

        expect(content).toBeNull()
      })
    })
  })
})
