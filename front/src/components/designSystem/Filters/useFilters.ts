import { useSearchParams } from 'react-router-dom'

import { useNavigate } from '~/core/router'
import { TimeGranularityEnum } from '~/generated/graphql'

import { useFilterContext } from './context'
import { AvailableFiltersEnum, AvailableQuickFilters, FiltersFormValues } from './types'
import { keyWithPrefix } from './utils'

export const useFilters = () => {
  const context = useFilterContext()
  const navigate = useNavigate()

  const [searchParams] = useSearchParams()
  const searchParamsObject = Object.fromEntries(searchParams.entries())

  const prefix = context.filtersNamePrefix

  const keyWithoutPrefix = (key: string) => (prefix ? key.replace(`${prefix}_`, '') : key)
  const localKeyWithPrefix = (key: string) => keyWithPrefix(key, prefix)

  const removeExistingFilters = () => {
    // Only remove the filters from the URL that are currently applied and are removable (availableFilters)
    for (const search in searchParamsObject) {
      const key = keyWithoutPrefix(search) as AvailableFiltersEnum

      // if value is part of the static filters, reset to default static value
      if (context.staticFilters?.[key]) {
        searchParams.set(search, context.staticFilters[key])
      } else if (context.availableFilters.includes(key)) {
        // otherwise, remove the filter from the URL
        searchParams.delete(search)
      }
    }
  }

  const resetFilters = () => {
    removeExistingFilters()

    navigate({ search: searchParams.toString() })
  }

  const applyFilters = (values: FiltersFormValues) => {
    removeExistingFilters()

    values.filters.forEach((filter) => {
      if (!filter.filterType || filter.value === undefined) {
        return
      }

      const withPrefix = localKeyWithPrefix(filter.filterType) as AvailableFiltersEnum
      const withoutPrefix = keyWithoutPrefix(filter.filterType) as AvailableFiltersEnum

      if (
        context.staticFilters?.[withoutPrefix] ||
        context.availableFilters.includes(withoutPrefix)
      ) {
        searchParams.delete(withPrefix)
      }

      searchParams.append(withPrefix, filter.value)
    })

    navigate({ search: searchParams.toString() })
  }

  const getInitialFiltersFormValues = (from: 'default' | 'url') => {
    // We sometimes want to get the initial filters from the URL and sometimes from the default filters at instantiation
    const source =
      from === 'default'
        ? Object.entries(context.staticFilters ?? {})
        : Object.entries(searchParamsObject)

    return source.reduce<FiltersFormValues['filters']>((acc, cur) => {
      const [_key, value] = cur as [AvailableFiltersEnum, FiltersFormValues['filters'][0]['value']]

      const key = keyWithoutPrefix(_key) as AvailableFiltersEnum

      if (!context.availableFilters.includes(key) && !context.staticFilters?.[key]) {
        return acc
      }

      return [
        ...acc,
        {
          filterType: key,
          value,
          disabled: !!context.staticFilters?.[key],
        },
      ]
    }, [])
  }

  const hasAppliedFilters = () => {
    if (searchParamsObject) {
      return Object.keys(searchParamsObject).some((key) =>
        context.availableFilters.includes(keyWithoutPrefix(key) as AvailableFiltersEnum),
      )
    }

    return false
  }

  const buildQuickFilterUrlParams = (filters: { [key: string]: unknown }) => {
    const staticFilters = Object.entries(context.staticFilters ?? {})
      .map(([key, value]) => `${localKeyWithPrefix(key)}=${value}`)
      .join('&')

    let newFilters = Object.entries(filters).map(([_key, value]) => {
      const key = localKeyWithPrefix(_key)

      if (Array.isArray(value)) {
        return `${key}=${value.join(',')}`
      }

      return `${key}=${value}`
    })

    Object.keys(searchParamsObject).forEach((key) => {
      if (!context.availableFilters.includes(keyWithoutPrefix(key) as AvailableFiltersEnum)) {
        newFilters = newFilters.concat(`${key}=${encodeURIComponent(searchParamsObject[key])}`)
      }
    })

    const newFiltersJoined = newFilters.join('&')

    // If there are no static filters, return only the new filters
    return staticFilters ? `${staticFilters}&${newFiltersJoined}` : newFiltersJoined
  }

  const selectTimeGranularity = (timeGranularity: TimeGranularityEnum): string => {
    const newSearchParams = new URLSearchParams(searchParams)

    newSearchParams.set(localKeyWithPrefix(AvailableQuickFilters.timeGranularity), timeGranularity)

    return newSearchParams.toString()
  }

  const isQuickFilterActive = (filters: { [key: string]: unknown }) => {
    for (const [_key, value] of Object.entries(filters)) {
      const key = localKeyWithPrefix(_key)

      if (Array.isArray(value)) {
        if (searchParamsObject[key] !== value.join(',')) {
          return false
        }
      } else {
        if (searchParamsObject[key] !== String(value)) {
          return false
        }
      }
    }

    return true
  }

  return {
    ...context,
    hasAppliedFilters: hasAppliedFilters(),
    initialFiltersFormValues: getInitialFiltersFormValues('url'),
    staticFiltersFormValues: getInitialFiltersFormValues('default'),
    applyFilters,
    buildQuickFilterUrlParams,
    isQuickFilterActive,
    keyWithoutPrefix,
    localKeyWithPrefix,
    resetFilters,
    selectTimeGranularity,
  }
}
