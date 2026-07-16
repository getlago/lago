import { useMemo } from 'react'

import { Button } from '~/components/designSystem/Button'
import { ComboBox, ComboBoxProps } from '~/components/form'
import { MappingTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { stringifyOptionValue } from './stringifyOptionValue'
import {
  XeroIntegrationMapItemFormWrapperFactoryProps,
  XeroIntegrationMapItemFormWrapperProps,
} from './types'
import { useXeroIntegrationMappingCRUD } from './useXeroIntegrationMappingCRUD'

/**
 * Those levels of deep calls are necessary just because of callback order.
 * React needs to have the callback called in the same order and since we are using a new hook in here but were not using one before
 * the element was built
 */

const XeroInput = ({
  formikProps,
  billingEntityKey,
  formType,
  integrationId,
}: XeroIntegrationMapItemFormWrapperProps & XeroIntegrationMapItemFormWrapperFactoryProps) => {
  const { translate } = useInternationalization()

  const {
    getXeroIntegrationItems,
    initialItemFetchLoading,
    initialItemFetchData,
    accountItemsLoading,
    itemsLoading,
    triggerAccountItemRefetch,
    triggerItemRefetch,
  } = useXeroIntegrationMappingCRUD(formType, integrationId)

  const isLoading = initialItemFetchLoading || itemsLoading || accountItemsLoading

  const comboboxData = useMemo(() => {
    return (initialItemFetchData?.integrationItems?.collection || []).map((item) => {
      const { externalId, externalName, externalAccountCode } = item

      return {
        label: `${externalName} (${externalAccountCode})`,
        description: externalId,
        value: stringifyOptionValue({
          externalId,
          externalName: externalName || '',
          externalAccountCode: externalAccountCode || '',
        }),
      }
    })
  }, [initialItemFetchData?.integrationItems?.collection])

  const isAccountContext = formType === MappingTypeEnum.Account

  const searchQuery = !!integrationId
    ? (getXeroIntegrationItems as unknown as ComboBoxProps['searchQuery'])
    : undefined

  const helperText =
    !isLoading && !comboboxData.length ? translate('text_6630ec823adac97d3bf0fb4b') : undefined

  const handleUpdateValue = (value: string) => {
    formikProps.setFieldValue(`${billingEntityKey}.selectedElementValue`, value)
  }

  const handleRefresh = () => {
    if (isAccountContext) {
      triggerAccountItemRefetch()
      return
    }

    triggerItemRefetch()
  }

  return (
    <div className="mb-8 flex flex-row gap-3">
      <div className="flex-1">
        <ComboBox
          // Only happens when the component is still initializing
          value={formikProps.values[billingEntityKey]?.selectedElementValue ?? ''}
          data={comboboxData}
          loading={isLoading}
          label={translate('text_6672ebb8b1b50be550eccb73')}
          placeholder={translate('text_6630e51df0a194013daea622')}
          helperText={helperText}
          searchQuery={searchQuery}
          onChange={handleUpdateValue}
          PopperProps={{ displayInDialog: true }}
        />
      </div>
      <Button
        className="mt-8"
        icon="reload"
        variant="quaternary"
        disabled={isLoading}
        loading={isLoading}
        onClick={handleRefresh}
      />
    </div>
  )
}

export function xeroIntegrationMapItemFormWrapperFactory({
  formType,
  integrationId,
}: XeroIntegrationMapItemFormWrapperFactoryProps) {
  const XeroIntegrationMapItemFormWrapper = ({
    formikProps,
    billingEntityKey,
  }: XeroIntegrationMapItemFormWrapperProps): JSX.Element => {
    return (
      <XeroInput
        formikProps={formikProps}
        billingEntityKey={billingEntityKey}
        formType={formType}
        integrationId={integrationId}
      />
    )
  }

  return XeroIntegrationMapItemFormWrapper
}
