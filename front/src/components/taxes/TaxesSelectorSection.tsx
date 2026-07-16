import { gql } from '@apollo/client'
import { useCallback, useMemo, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { ComboBox, ComboboxItem } from '~/components/form'
import { MUI_INPUT_BASE_ROOT_CLASSNAME } from '~/core/constants/form'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { scrollToAndClickElement } from '~/core/utils/domUtils'
import {
  TaxForTaxesSelectorSectionFragment,
  TaxForTaxesSelectorSectionFragmentDoc,
  useGetTaxesForTaxesSelectorSectionLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

// Test ID constants
export const TAXES_SELECTOR_SECTION_TEST_ID = 'taxes-selector-section'
export const TAXES_SELECTOR_TITLE_TEST_ID = 'taxes-selector-title'
export const TAXES_SELECTOR_DESCRIPTION_TEST_ID = 'taxes-selector-description'
export const TAXES_SELECTOR_LIST_TEST_ID = 'taxes-selector-list'
export const TAXES_SELECTOR_ADD_BUTTON_TEST_ID = 'taxes-selector-add-button'
export const TAXES_SELECTOR_COMBOBOX_CONTAINER_TEST_ID = 'taxes-selector-combobox-container'
export const TAXES_SELECTOR_DISMISS_BUTTON_TEST_ID = 'taxes-selector-dismiss-button'
export const buildTaxChipTestId = (taxId: string): string => `tax-chip-${taxId}`

gql`
  fragment TaxForTaxesSelectorSection on Tax {
    id
    code
    name
    rate
  }

  query getTaxesForTaxesSelectorSection($limit: Int, $page: Int, $searchTerm: String) {
    taxes(limit: $limit, page: $page, searchTerm: $searchTerm) {
      metadata {
        currentPage
        totalPages
      }
      collection {
        id
        ...TaxForTaxesSelectorSection
      }
    }
  }

  ${TaxForTaxesSelectorSectionFragmentDoc}
`

export type TaxesSelectorSectionProps<T extends TaxForTaxesSelectorSectionFragment> = {
  title: string
  description?: string
  taxes: T[]
  comboboxSelector: string
  onUpdate: (newTaxArray: T[]) => void
}

export const TaxesSelectorSection = <T extends TaxForTaxesSelectorSectionFragment>({
  title,
  description,
  taxes,
  comboboxSelector,
  onUpdate,
}: TaxesSelectorSectionProps<T>): JSX.Element => {
  const { translate } = useInternationalization()
  const [shouldDisplayTaxesInput, setShouldDisplayTaxesInput] = useState<boolean>(false)

  const [getTaxes, { data: taxesData, loading: taxesLoading }] =
    useGetTaxesForTaxesSelectorSectionLazyQuery({
      variables: { limit: 500 },
    })
  const { collection: taxesCollection } = taxesData?.taxes || {}

  const taxesDataForCombobox = useMemo(() => {
    if (!taxesCollection) return []

    const chargeTaxesIds = taxes?.map((tax) => tax.id) || []

    return taxesCollection.map(({ id: taxId, name, rate }) => {
      const formatedRate = intlFormatNumber(Number(rate) / 100 || 0, {
        style: 'percent',
      })

      return {
        label: `${name} (${formatedRate})`,
        labelNode: (
          <ComboboxItem>
            <Typography variant="body" color="grey700" noWrap>
              {name}
            </Typography>
            <Typography variant="caption" color="grey600" noWrap>
              {formatedRate}
            </Typography>
          </ComboboxItem>
        ),
        value: taxId,
        disabled: chargeTaxesIds.includes(taxId),
      }
    })
  }, [taxes, taxesCollection])

  const deleteTax = useCallback(
    (taxIdToDelete: string) => {
      const newTaxedArray = taxes?.filter((tax) => tax.id !== taxIdToDelete) || []

      onUpdate(newTaxedArray)
    },
    [onUpdate, taxes],
  )

  const onSelectNewTax = useCallback(
    (newTaxId: string) => {
      const previousTaxes = [...(taxes || [])]
      const newTaxObject = taxesData?.taxes.collection.find((t) => t.id === newTaxId)

      onUpdate([...previousTaxes, newTaxObject] as T[])
      setShouldDisplayTaxesInput(false)
    },
    [onUpdate, taxes, taxesData],
  )

  return (
    <div className="flex flex-col gap-3" data-test={TAXES_SELECTOR_SECTION_TEST_ID}>
      <div className="flex flex-col gap-1">
        <Typography variant="captionHl" color="grey700" data-test={TAXES_SELECTOR_TITLE_TEST_ID}>
          {title}
        </Typography>
        {description && (
          <Typography
            variant="caption"
            color="grey600"
            data-test={TAXES_SELECTOR_DESCRIPTION_TEST_ID}
          >
            {description}
          </Typography>
        )}
      </div>

      {!!taxes?.length && (
        <div className="flex flex-wrap items-center gap-3" data-test={TAXES_SELECTOR_LIST_TEST_ID}>
          {taxes.map(({ id: localTaxId, name, rate }) => (
            <Chip
              key={localTaxId}
              data-test={buildTaxChipTestId(localTaxId)}
              label={`${name} (${rate}%)`}
              type="secondary"
              size="medium"
              deleteIcon="trash"
              icon="percentage"
              deleteIconLabel={translate('text_63aa085d28b8510cd46443ff')}
              onDelete={() => deleteTax(localTaxId)}
            />
          ))}
        </div>
      )}

      {!shouldDisplayTaxesInput && (
        <Button
          fitContent
          startIcon="plus"
          variant="inline"
          onClick={() => {
            setShouldDisplayTaxesInput(true)

            scrollToAndClickElement({
              selector: `.${comboboxSelector} .${MUI_INPUT_BASE_ROOT_CLASSNAME}`,
            })
          }}
          data-test={TAXES_SELECTOR_ADD_BUTTON_TEST_ID}
        >
          {translate('text_64be910fba8ef9208686a8c9')}
        </Button>
      )}

      {shouldDisplayTaxesInput && (
        <div
          className="flex items-center gap-3"
          data-test={TAXES_SELECTOR_COMBOBOX_CONTAINER_TEST_ID}
        >
          <ComboBox
            containerClassName="flex-1"
            className={comboboxSelector}
            data={taxesDataForCombobox}
            searchQuery={getTaxes}
            loading={taxesLoading}
            placeholder={translate('text_64be910fba8ef9208686a8e7')}
            emptyText={translate('text_64be91fd0678965126e5657b')}
            onChange={onSelectNewTax}
          />

          <Tooltip placement="top-end" title={translate('text_63aa085d28b8510cd46443ff')}>
            <Button
              icon="trash"
              variant="quaternary"
              data-test={TAXES_SELECTOR_DISMISS_BUTTON_TEST_ID}
              onClick={() => setShouldDisplayTaxesInput(false)}
            />
          </Tooltip>
        </div>
      )}
    </div>
  )
}
