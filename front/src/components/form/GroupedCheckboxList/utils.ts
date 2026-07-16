import { CheckboxGroup, GroupingMap, RowConfigWithSublabel } from './types'

/**
 * Creates a map of groups for easier lookup by group ID.
 */
export const createGroupingMap = (groups: CheckboxGroup[]): GroupingMap => {
  return groups.reduce<GroupingMap>((acc, g) => {
    acc[g.id] = {
      id: g.id,
      label: g.label,
      items: g.items,
    }
    return acc
  }, {})
}

/**
 * Creates empty boolean values (all false) from a list of checkbox groups.
 * Useful for initializing form default values.
 */
export const createEmptyValuesFromGroups = (groups: CheckboxGroup[]): Record<string, boolean> => {
  return groups.reduce<Record<string, boolean>>((acc, group) => {
    group.items.forEach((item) => {
      acc[item.id] = false
    })
    return acc
  }, {})
}

/**
 * Transforms checkbox groups into flat row configuration for TableWithGroups.
 */
export const getDataRows = (groups: CheckboxGroup[]): RowConfigWithSublabel[] => {
  return groups.reduce<RowConfigWithSublabel[]>((acc, g) => {
    acc.push({
      label: g.label,
      key: g.id,
      type: 'group',
    })

    g.items.forEach((item) => {
      acc.push({
        label: item.label,
        sublabel: item.sublabel,
        key: item.id,
        type: 'line',
        groupKey: g.id,
      })
    })

    return acc
  }, [])
}

/**
 * Calculates the overall checkbox state based on all values.
 * Returns:
 * - true: all items are checked
 * - false: no items are checked
 * - undefined: some items are checked (indeterminate state)
 */
export const getOverallCheckboxValue = (
  checkboxValues: Record<string, boolean>,
): boolean | undefined => {
  const values = Object.values(checkboxValues)

  if (values.length === 0) return false

  const allTrue = values.every((value) => value === true)
  const allFalse = values.every((value) => value === false)

  if (allTrue) {
    return true
  }

  if (allFalse) {
    return false
  }

  return undefined
}

/**
 * Calculates the checkbox state for a specific group.
 * Returns:
 * - true: all items in the group are checked
 * - false: no items in the group are checked
 * - undefined: some items are checked (indeterminate state)
 */
export const getGroupCheckboxValue = (
  groupId: string,
  groupingMap: GroupingMap,
  checkboxValues: Record<string, boolean>,
): boolean | undefined => {
  const groupData = groupingMap[groupId]

  if (!groupData) return false

  const totalNumberOfItems = groupData.items.length
  const numberOfEnabledItems = groupData.items.filter((item) => checkboxValues[item.id]).length

  if (numberOfEnabledItems === 0) {
    return false
  } else if (numberOfEnabledItems === totalNumberOfItems) {
    return true
  }

  return undefined
}

/**
 * Filters rows based on search term.
 * Matches against group labels, item labels, and item sublabels.
 * When a group matches, all its items are included.
 */
export const filterRowsBySearchTerm = (
  rows: RowConfigWithSublabel[],
  groups: CheckboxGroup[],
  searchTerm: string,
): RowConfigWithSublabel[] => {
  if (!searchTerm.trim()) return rows

  const searchLower = searchTerm.toLowerCase()
  const matchingGroups = new Set<string>()
  const matchingItems = new Set<string>()

  groups.forEach((g) => {
    const groupMatches = g.label.toLowerCase().includes(searchLower)

    if (groupMatches) {
      // Group name matches - include all its items
      matchingGroups.add(g.id)
      g.items.forEach((item) => matchingItems.add(item.id))
    } else {
      // Check individual items
      g.items.forEach((item) => {
        const labelMatches = item.label.toLowerCase().includes(searchLower)
        const sublabelMatches = item.sublabel?.toLowerCase().includes(searchLower)

        if (labelMatches || sublabelMatches) {
          matchingItems.add(item.id)
          matchingGroups.add(g.id) // Include parent group
        }
      })
    }
  })

  return rows.filter((row) => {
    if (row.type === 'group') return matchingGroups.has(row.key)
    if (row.type === 'line') return matchingItems.has(row.key)
    return true
  })
}

/**
 * Finds group IDs that should be expanded based on search matches.
 */
export const getGroupsToExpandForSearch = (
  groups: CheckboxGroup[],
  searchTerm: string,
): string[] => {
  if (!searchTerm.trim()) return []

  const searchLower = searchTerm.toLowerCase()
  const groupsToExpand: string[] = []

  groups.forEach((g) => {
    const groupMatches = g.label.toLowerCase().includes(searchLower)
    const hasMatchingItem = g.items.some((item) => {
      const labelMatches = item.label.toLowerCase().includes(searchLower)
      const sublabelMatches = item.sublabel?.toLowerCase().includes(searchLower)

      return labelMatches || sublabelMatches
    })

    if (groupMatches || hasMatchingItem) {
      groupsToExpand.push(g.id)
    }
  })

  return groupsToExpand
}

/**
 * Counts enabled items in a group.
 */
export const countEnabledItemsInGroup = (
  groupId: string,
  groupingMap: GroupingMap,
  checkboxValues: Record<string, boolean>,
): { enabled: number; total: number } => {
  const groupData = groupingMap[groupId]

  if (!groupData) return { enabled: 0, total: 0 }

  const total = groupData.items.length
  const enabled = groupData.items.filter((item) => checkboxValues[item.id]).length

  return { enabled, total }
}
