import Stack from '@mui/material/Stack'
import { useFormik } from 'formik'
import { tw } from 'lago-design-system'
import { useMemo, useRef } from 'react'
import { array, lazy, object, string } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { FiltersItemDates, METADATA_SPLITTER } from '~/components/designSystem/Filters/utils'
import { Popper } from '~/components/designSystem/Popper'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { ComboBox } from '~/components/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FiltersPanelItemTypeSwitch } from './FiltersPanelItemTypeSwitch'
import { AvailableFiltersEnum, FiltersFormValues, mapFilterToTranslationKey } from './types'
import { useFilters } from './useFilters'

export const FiltersPanelPopper = () => {
  const { translate } = useInternationalization()
  const {
    availableFilters,
    initialFiltersFormValues,
    staticFiltersFormValues,
    applyFilters,
    buttonOpener,
    displayInDialog,
  } = useFilters()

  const listContainerElementRef = useRef<HTMLDivElement>(null)

  const formikProps = useFormik<FiltersFormValues>({
    initialValues: {
      // Default has to contain an empty object to display the first filter placeholder
      filters: !!initialFiltersFormValues.length ? [...initialFiltersFormValues] : [{}],
    },
    validateOnMount: true,
    enableReinitialize: true,
    onSubmit: applyFilters,
    validationSchema: object().shape({
      filters: lazy((value: FiltersFormValues['filters']) => {
        // Make sure schema is valid on "Clear all" button press
        if (
          initialFiltersFormValues.length > 0 &&
          value.length === 1 &&
          Object.keys(value[0]).length === 0
        ) {
          return array().of(object())
        }

        return array().of(
          object().shape({
            filterType: string().required(''),
            value: string()
              .when('filterType', {
                is: (filterType: AvailableFiltersEnum) =>
                  !!filterType &&
                  FiltersItemDates.includes(filterType) &&
                  filterType !== AvailableFiltersEnum.metadata,
                then: (schema) => schema.matches(/\w+,\w+/, '').required(''),
                otherwise: (schema) => schema.required(''),
              })
              .when('filterType', {
                is: (filterType: AvailableFiltersEnum) =>
                  filterType === AvailableFiltersEnum.metadata,
                then: (schema) =>
                  schema.test({
                    name: 'metadata-format',
                    message: '',
                    test: (v) => {
                      if (!v) {
                        return false
                      }

                      const metadatas = v.split(METADATA_SPLITTER)

                      if (metadatas.length > 5) {
                        return false
                      }

                      if (metadatas.some((m) => !m.includes('='))) {
                        return false
                      }

                      return metadatas.every((m) => {
                        const [a, b] = m.split('=')

                        return !!a && !!b
                      })
                    },
                  }),
              }),
          }),
        )
      }),
    }),
  })

  const comboboxFiltersData = useMemo(() => {
    const alreadySelectedFiltersTypes = formikProps.values.filters.map(
      (filter) => filter.filterType,
    )

    return availableFilters.map((filter) => {
      return {
        label: translate(mapFilterToTranslationKey(filter)),
        value: filter,
        disabled: alreadySelectedFiltersTypes.includes(filter),
      }
    })
  }, [formikProps.values.filters, availableFilters, translate])

  const onRemoveFilter = (filterIndex: number) => {
    const newFilters = formikProps.values.filters.filter((_, index) => index !== filterIndex)

    formikProps.setFieldValue('filters', newFilters)
  }

  return (
    <Popper
      displayInDialog={displayInDialog}
      PopperProps={{ placement: 'bottom-start' }}
      opener={
        buttonOpener || (
          <Button startIcon="filter" size="small" variant="quaternary">
            {translate('text_66ab42d4ece7e6b7078993ad')}
          </Button>
        )
      }
    >
      {({ closePopper }) => (
        /* About w-[calc(100vw_-_2px)], we needed to force the container to stick on max-width */
        /* Also, need to remove 2px to prevent border to get out of screen view, and trigger underlying elements scroll to be trigger by scroll on the popper element: https://linear.app/getlago/issue/LAGO-180/when-panel-touch-screen-borders-window-can-scroll-horizontally */
        <div className="grid max-h-[480px] w-[calc(100vw_-_2px)] max-w-[864px] grid-rows-[64px_1fr_72px]">
          <div className="flex h-16 items-center justify-between px-4 py-0 shadow-b lg:px-6">
            <Typography variant="bodyHl" color="grey700">
              {translate('text_66ab42d4ece7e6b7078993ad')}
            </Typography>
            <Button
              onClick={() => {
                formikProps.setFieldValue(
                  'filters',
                  staticFiltersFormValues.length ? staticFiltersFormValues : [{}],
                )
              }}
              variant="quaternary"
            >
              {translate('text_66ab42d4ece7e6b7078993a9')}
            </Button>
          </div>
          <div
            className="flex flex-col gap-6 overflow-y-auto p-4 lg:gap-3 lg:px-6 lg:py-4"
            ref={listContainerElementRef}
          >
            {formikProps.values.filters.map((filter, filterIndex) => (
              <div
                key={`filter-item-${filterIndex}`}
                className="border-1 flex flex-col justify-start gap-4 rounded-xl border border-solid border-grey-300 p-4 lg:flex-1 lg:flex-row lg:border-none lg:p-0"
              >
                {
                  // h = 48px to mimic the height of the ComboBox
                }
                <div className="flex lg:h-12 lg:w-[49px] lg:items-center">
                  <div className="block lg:hidden">
                    <Typography variant="bodyHl" color="grey700">
                      {`${translate('text_65e9c6d183491188fbbcf070')} ${filterIndex + 1}`}
                    </Typography>
                  </div>
                  <div className="hidden lg:block">
                    {filterIndex === 0 ? (
                      <Typography variant="body" color="grey700">
                        {translate('text_66ab42d4ece7e6b7078993b5')}
                      </Typography>
                    ) : (
                      <Typography variant="body" color="grey700">
                        {translate('text_65f8472df7593301061e27d6').toLowerCase()}
                      </Typography>
                    )}
                  </div>
                </div>
                {
                  // Metadata behaves differently, needs more space and is designed as a whole block on its own
                }
                <div
                  className={tw(
                    'flex flex-col justify-start gap-2 lg:flex-1 lg:flex-row lg:gap-3 lg:[&>div:first-child]:w-[200px] lg:[&>div:last-child]:flex-1',
                    {
                      'rounded-xl border border-grey-300 p-3': filter.filterType === 'metadata',
                      'lg:items-center': filter.filterType !== 'metadata',
                    },
                  )}
                >
                  <ComboBox
                    PopperProps={{
                      displayInDialog,
                    }}
                    disableClearable
                    data={comboboxFiltersData}
                    placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
                    value={filter.filterType}
                    disabled={filter.disabled}
                    onChange={(value) => {
                      const newFilterObject = {
                        ...formikProps.values.filters[filterIndex],
                        filterType: value,
                        // Value needs to be reset when changing type
                        value: undefined,
                      }

                      formikProps.setFieldValue(`filters[${filterIndex}]`, newFilterObject)
                    }}
                  />

                  <FiltersPanelItemTypeSwitch
                    filterType={filter.filterType}
                    value={filter.value}
                    setFilterValue={(value: string) => {
                      formikProps.setFieldValue(`filters[${filterIndex}].value`, value)
                    }}
                  />
                </div>

                {/* Actions */}
                {!filter.disabled && (
                  <>
                    <div className="block lg:hidden">
                      <Button
                        fitContent
                        align="left"
                        size="small"
                        startIcon="trash"
                        variant="quaternary"
                        disabled={formikProps.values.filters.length === 1}
                        onClick={() => onRemoveFilter(filterIndex)}
                      >
                        {translate('text_66ab4ad87fc8510054f237c2')}
                      </Button>
                    </div>
                    <div className="hidden lg:block">
                      <Tooltip
                        title={translate('text_63ea0f84f400488553caa786')}
                        placement="top-end"
                        disableHoverListener={formikProps.values.filters.length === 1}
                      >
                        <Button
                          icon="trash"
                          variant="quaternary"
                          disabled={formikProps.values.filters.length === 1}
                          onClick={() => onRemoveFilter(filterIndex)}
                        />
                      </Tooltip>
                    </div>
                  </>
                )}
              </div>
            ))}
          </div>
          <div className="flex h-18 items-center justify-between px-4 py-0 shadow-t lg:px-6">
            <Button
              startIcon="plus"
              disabled={formikProps.values.filters.length === availableFilters.length}
              onClick={() => {
                formikProps.setFieldValue('filters', [...formikProps.values.filters, {}])

                // After adding a new filter, scroll to the bottom of the container
                setTimeout(() => {
                  listContainerElementRef.current?.scrollTo({
                    top: listContainerElementRef.current.scrollHeight,
                    behavior: 'smooth',
                  })
                })
              }}
              variant="inline"
            >
              {translate('text_66ab42d4ece7e6b7078993b9')}
            </Button>

            <Stack direction="row" spacing={2}>
              <Button
                onClick={() => {
                  closePopper()
                  formikProps.resetForm()
                }}
                variant="quaternary"
              >
                {translate('text_6411e6b530cb47007488b027')}
              </Button>
              <Button
                disabled={!formikProps.dirty || !formikProps.isValid}
                onClick={() => {
                  formikProps.submitForm()
                  closePopper()
                }}
                variant="primary"
              >
                {translate('text_66ab42d4ece7e6b7078993c1')}
              </Button>
            </Stack>
          </div>
        </div>
      )}
    </Popper>
  )
}
