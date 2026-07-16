import { CheckboxGroup } from '../types'
import {
  countEnabledItemsInGroup,
  createEmptyValuesFromGroups,
  createGroupingMap,
  filterRowsBySearchTerm,
  getDataRows,
  getGroupCheckboxValue,
  getGroupsToExpandForSearch,
  getOverallCheckboxValue,
} from '../utils'

const mockGroups: CheckboxGroup[] = [
  {
    id: 'customers',
    label: 'Customers',
    items: [
      { id: 'customer.create', label: 'Create customer' },
      { id: 'customer.update', label: 'Update customer' },
      { id: 'customer.delete', label: 'Delete customer', sublabel: 'Permanently remove' },
    ],
  },
  {
    id: 'invoices',
    label: 'Invoices',
    items: [
      { id: 'invoice.create', label: 'Create invoice' },
      { id: 'invoice.view', label: 'View invoice' },
    ],
  },
]

describe('GroupedCheckboxList utils', () => {
  describe('createEmptyValuesFromGroups', () => {
    describe('GIVEN a list of checkbox groups', () => {
      describe('WHEN creating empty values', () => {
        it('THEN returns all items set to false', () => {
          const result = createEmptyValuesFromGroups(mockGroups)

          expect(result).toEqual({
            'customer.create': false,
            'customer.update': false,
            'customer.delete': false,
            'invoice.create': false,
            'invoice.view': false,
          })
        })
      })
    })

    describe('GIVEN an empty groups array', () => {
      describe('WHEN creating empty values', () => {
        it('THEN returns empty object', () => {
          const result = createEmptyValuesFromGroups([])

          expect(result).toEqual({})
        })
      })
    })
  })

  describe('createGroupingMap', () => {
    describe('GIVEN a list of checkbox groups', () => {
      describe('WHEN creating a grouping map', () => {
        it('THEN returns a map indexed by group id', () => {
          const result = createGroupingMap(mockGroups)

          expect(Object.keys(result)).toEqual(['customers', 'invoices'])
          expect(result.customers.id).toBe('customers')
          expect(result.customers.label).toBe('Customers')
          expect(result.customers.items).toHaveLength(3)
        })
      })
    })
  })

  describe('getDataRows', () => {
    describe('GIVEN a list of checkbox groups', () => {
      describe('WHEN transforming to rows', () => {
        it('THEN returns flat row structure with groups and items', () => {
          const result = getDataRows(mockGroups)

          expect(result).toHaveLength(7) // 2 groups + 5 items
        })

        it('THEN group rows have correct structure', () => {
          const result = getDataRows(mockGroups)

          expect(result[0]).toEqual({
            label: 'Customers',
            key: 'customers',
            type: 'group',
          })
        })

        it('THEN item rows have correct structure with groupKey', () => {
          const result = getDataRows(mockGroups)

          expect(result[1]).toEqual({
            label: 'Create customer',
            sublabel: undefined,
            key: 'customer.create',
            type: 'line',
            groupKey: 'customers',
          })
        })

        it('THEN item rows preserve sublabel when present', () => {
          const result = getDataRows(mockGroups)

          expect(result[3]).toEqual({
            label: 'Delete customer',
            sublabel: 'Permanently remove',
            key: 'customer.delete',
            type: 'line',
            groupKey: 'customers',
          })
        })
      })
    })

    describe('GIVEN an empty groups array', () => {
      describe('WHEN transforming to rows', () => {
        it('THEN returns empty array', () => {
          const result = getDataRows([])

          expect(result).toEqual([])
        })
      })
    })
  })

  describe('getOverallCheckboxValue', () => {
    describe('GIVEN all checkbox values are true', () => {
      describe('WHEN getting overall value', () => {
        it('THEN returns true', () => {
          const values = {
            'customer.create': true,
            'customer.update': true,
            'invoice.create': true,
          }

          expect(getOverallCheckboxValue(values)).toBe(true)
        })
      })
    })

    describe('GIVEN all checkbox values are false', () => {
      describe('WHEN getting overall value', () => {
        it('THEN returns false', () => {
          const values = {
            'customer.create': false,
            'customer.update': false,
            'invoice.create': false,
          }

          expect(getOverallCheckboxValue(values)).toBe(false)
        })
      })
    })

    describe('GIVEN mixed checkbox values', () => {
      describe('WHEN getting overall value', () => {
        it('THEN returns undefined (indeterminate)', () => {
          const values = {
            'customer.create': true,
            'customer.update': false,
            'invoice.create': true,
          }

          expect(getOverallCheckboxValue(values)).toBeUndefined()
        })
      })
    })

    describe('GIVEN empty checkbox values', () => {
      describe('WHEN getting overall value', () => {
        it('THEN returns false', () => {
          expect(getOverallCheckboxValue({})).toBe(false)
        })
      })
    })
  })

  describe('getGroupCheckboxValue', () => {
    const groupingMap = createGroupingMap(mockGroups)

    describe('GIVEN all items in a group are checked', () => {
      describe('WHEN getting group checkbox value', () => {
        it('THEN returns true', () => {
          const values = {
            'customer.create': true,
            'customer.update': true,
            'customer.delete': true,
            'invoice.create': false,
            'invoice.view': false,
          }

          expect(getGroupCheckboxValue('customers', groupingMap, values)).toBe(true)
        })
      })
    })

    describe('GIVEN no items in a group are checked', () => {
      describe('WHEN getting group checkbox value', () => {
        it('THEN returns false', () => {
          const values = {
            'customer.create': false,
            'customer.update': false,
            'customer.delete': false,
            'invoice.create': true,
            'invoice.view': true,
          }

          expect(getGroupCheckboxValue('customers', groupingMap, values)).toBe(false)
        })
      })
    })

    describe('GIVEN some items in a group are checked', () => {
      describe('WHEN getting group checkbox value', () => {
        it('THEN returns undefined (indeterminate)', () => {
          const values = {
            'customer.create': true,
            'customer.update': false,
            'customer.delete': true,
            'invoice.create': false,
            'invoice.view': false,
          }

          expect(getGroupCheckboxValue('customers', groupingMap, values)).toBeUndefined()
        })
      })
    })

    describe('GIVEN a non-existent group id', () => {
      describe('WHEN getting group checkbox value', () => {
        it('THEN returns false', () => {
          const values = { 'customer.create': true }

          expect(getGroupCheckboxValue('nonexistent', groupingMap, values)).toBe(false)
        })
      })
    })
  })

  describe('filterRowsBySearchTerm', () => {
    const rows = getDataRows(mockGroups)

    describe('GIVEN an empty search term', () => {
      describe('WHEN filtering rows', () => {
        it('THEN returns all rows unchanged', () => {
          expect(filterRowsBySearchTerm(rows, mockGroups, '')).toEqual(rows)
          expect(filterRowsBySearchTerm(rows, mockGroups, '   ')).toEqual(rows)
        })
      })
    })

    describe('GIVEN a search term matching a group name', () => {
      describe('WHEN filtering rows', () => {
        it('THEN returns the group and all its items', () => {
          const result = filterRowsBySearchTerm(rows, mockGroups, 'customers')

          expect(result).toHaveLength(4)
          expect(result[0].key).toBe('customers')
          expect(result.map((r) => r.key)).toContain('customer.create')
        })
      })
    })

    describe('GIVEN a search term matching item labels', () => {
      describe('WHEN filtering rows', () => {
        it('THEN returns matching items and their parent groups', () => {
          const result = filterRowsBySearchTerm(rows, mockGroups, 'create')

          expect(result.some((r) => r.key === 'customer.create')).toBe(true)
          expect(result.some((r) => r.key === 'invoice.create')).toBe(true)
          expect(result.some((r) => r.key === 'customers')).toBe(true)
          expect(result.some((r) => r.key === 'invoices')).toBe(true)
        })
      })
    })

    describe('GIVEN a search term matching a sublabel', () => {
      describe('WHEN filtering rows', () => {
        it('THEN returns the item and its parent group', () => {
          const result = filterRowsBySearchTerm(rows, mockGroups, 'permanently')

          expect(result.some((r) => r.key === 'customer.delete')).toBe(true)
          expect(result.some((r) => r.key === 'customers')).toBe(true)
        })
      })
    })

    describe('GIVEN a search term with different casing', () => {
      describe('WHEN filtering rows', () => {
        it('THEN matches case-insensitively', () => {
          const result = filterRowsBySearchTerm(rows, mockGroups, 'CUSTOMERS')

          expect(result).toHaveLength(4)
        })
      })
    })

    describe('GIVEN a search term with no matches', () => {
      describe('WHEN filtering rows', () => {
        it('THEN returns empty array', () => {
          const result = filterRowsBySearchTerm(rows, mockGroups, 'xyz123')

          expect(result).toHaveLength(0)
        })
      })
    })
  })

  describe('getGroupsToExpandForSearch', () => {
    describe('GIVEN an empty search term', () => {
      describe('WHEN getting groups to expand', () => {
        it('THEN returns empty array', () => {
          expect(getGroupsToExpandForSearch(mockGroups, '')).toEqual([])
          expect(getGroupsToExpandForSearch(mockGroups, '   ')).toEqual([])
        })
      })
    })

    describe('GIVEN a search term matching a group name', () => {
      describe('WHEN getting groups to expand', () => {
        it('THEN returns that group id', () => {
          const result = getGroupsToExpandForSearch(mockGroups, 'invoices')

          expect(result).toEqual(['invoices'])
        })
      })
    })

    describe('GIVEN a search term matching items in multiple groups', () => {
      describe('WHEN getting groups to expand', () => {
        it('THEN returns all matching group ids', () => {
          const result = getGroupsToExpandForSearch(mockGroups, 'create')

          expect(result).toContain('customers')
          expect(result).toContain('invoices')
        })
      })
    })

    describe('GIVEN a search term matching a sublabel', () => {
      describe('WHEN getting groups to expand', () => {
        it('THEN returns the parent group id', () => {
          const result = getGroupsToExpandForSearch(mockGroups, 'permanently')

          expect(result).toEqual(['customers'])
        })
      })
    })
  })

  describe('countEnabledItemsInGroup', () => {
    const groupingMap = createGroupingMap(mockGroups)

    describe('GIVEN a group with some enabled items', () => {
      describe('WHEN counting enabled items', () => {
        it('THEN returns correct enabled and total counts', () => {
          const values = {
            'customer.create': true,
            'customer.update': false,
            'customer.delete': true,
            'invoice.create': false,
            'invoice.view': false,
          }

          expect(countEnabledItemsInGroup('customers', groupingMap, values)).toEqual({
            enabled: 2,
            total: 3,
          })

          expect(countEnabledItemsInGroup('invoices', groupingMap, values)).toEqual({
            enabled: 0,
            total: 2,
          })
        })
      })
    })

    describe('GIVEN a non-existent group id', () => {
      describe('WHEN counting enabled items', () => {
        it('THEN returns zeros', () => {
          expect(countEnabledItemsInGroup('nonexistent', groupingMap, {})).toEqual({
            enabled: 0,
            total: 0,
          })
        })
      })
    })
  })
})
