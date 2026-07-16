import { gql } from '@apollo/client'
import { tw } from 'lago-design-system'
import { useId, useMemo, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { MultipleComboBox } from '~/components/form'
import { useChargeFormContext, usePropertyValues } from '~/contexts/ChargeFormContext'
import {
  MUI_INPUT_BASE_ROOT_CLASSNAME,
  SEARCH_PRICING_GROUP_KEY_INPUT_CLASSNAME,
} from '~/core/constants/form'
import { scrollToAndClickElement } from '~/core/utils/domUtils'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment PricingGroupKeys on Properties {
    pricingGroupKeys
  }
`

const PricingGroupKeys = () => {
  const { form, propertyCursor, disabled } = useChargeFormContext()
  const valuePointer = usePropertyValues(form, propertyCursor)
  const componentId = useId()
  const { translate } = useInternationalization()

  const currentSearchClassName = useMemo(() => {
    // Replace all colons with dashes to make the class name valid for querySelector
    const usableComponentId = componentId.replace(/:/g, '-')

    return `${SEARCH_PRICING_GROUP_KEY_INPUT_CLASSNAME}-${usableComponentId}`
  }, [componentId])

  const [shouldDisplayPricingGroupKeys, setShouldDisplayPricingGroupKeys] = useState<boolean>(false)

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-1">
        <Typography variant="captionHl" color="textSecondary">
          {translate('text_65ba6d45e780c1ff8acb20ce')}
        </Typography>
        <Typography variant="caption">{translate('text_6661fc17337de3591e29e425')}</Typography>
      </div>
      <div className="flex flex-col gap-3">
        {!!valuePointer?.pricingGroupKeys?.length && (
          <div className="flex flex-wrap gap-2">
            {valuePointer?.pricingGroupKeys?.map((groupKey, groupKeyIndex) => (
              <Chip
                key={`pricing-groupe-key-chip-${groupKey}-${groupKeyIndex}`}
                label={groupKey}
                onDelete={() => {
                  const newPricingGroupKeys = valuePointer?.pricingGroupKeys?.filter(
                    (_, index) => index !== groupKeyIndex,
                  )

                  form.setFieldValue(
                    `${propertyCursor}.pricingGroupKeys`,
                    newPricingGroupKeys || [],
                  )
                }}
              />
            ))}
          </div>
        )}

        {shouldDisplayPricingGroupKeys ? (
          <div className="flex gap-3">
            <MultipleComboBox
              freeSolo
              hideTags
              disableClearable
              showOptionsOnlyWhenTyping
              className={tw('flex-1', currentSearchClassName)}
              data={[]}
              disabled={disabled}
              onChange={(newValue) => {
                const transformedValue = newValue?.map((item) => item.value) || undefined

                form.setFieldValue(`${propertyCursor}.pricingGroupKeys`, transformedValue)
              }}
              value={(valuePointer?.pricingGroupKeys || []).map((key) => ({ value: key }))}
              placeholder={translate('text_65ba6d45e780c1ff8acb206f')}
            />

            <Tooltip
              className="mt-1"
              placement="top-end"
              title={translate('text_63aa085d28b8510cd46443ff')}
            >
              <Button
                icon="trash"
                variant="quaternary"
                onClick={() => {
                  setShouldDisplayPricingGroupKeys(false)
                }}
              />
            </Tooltip>
          </div>
        ) : (
          <Button
            fitContent
            startIcon="plus"
            variant="inline"
            onClick={() => {
              setShouldDisplayPricingGroupKeys(true)

              scrollToAndClickElement({
                selector: `.${currentSearchClassName} .${MUI_INPUT_BASE_ROOT_CLASSNAME}`,
              })
            }}
          >
            {translate('text_1773692639715a1g5pyyfj3n')}
          </Button>
        )}
      </div>
    </div>
  )
}

export default PricingGroupKeys
