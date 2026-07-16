import { isNil } from 'lodash'

type DataMaskEntry = {
  filterState?: Record<string, unknown>
}

type NativeFilters = Record<string, { filterState: Record<string, unknown> }>

export function extractNativeFilters(dataMask: Record<string, unknown>): NativeFilters {
  return Object.entries(dataMask).reduce<NativeFilters>((acc, [key, entry]) => {
    const filterState = (entry as DataMaskEntry)?.filterState
    const val = filterState?.value

    if (
      key.startsWith('NATIVE_FILTER-') &&
      filterState &&
      !isNil(val) &&
      !(Array.isArray(val) && val.length === 0)
    ) {
      acc[key] = { filterState }
    }

    return acc
  }, {})
}
