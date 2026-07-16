import { useStore } from '@tanstack/react-form'
import React from 'react'

import { Accordion } from '~/components/designSystem/Accordion'
import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { isZodErrors } from '~/core/form/isZodErrors'
import {
  METADATA_VALUE_MAX_LENGTH_DEFAULT,
  MetadataErrorsEnum,
} from '~/formValidation/metadataSchema'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'
import { tw } from '~/styles/utils'

const MAX_METADATA_COUNT = 5

const MetadataAccordion = withForm({
  defaultValues: emptyCreateCustomerDefaultValues,
  render: function Render({ form }) {
    const { translate } = useInternationalization()
    const gridClassName = 'grid grid-cols-[200px_1fr_60px_24px] gap-x-3 gap-y-6'

    const getMetadataError = (errors: unknown): string => {
      if (!isZodErrors(errors)) return ''

      return errors.map((e) => e.message).join('')
    }

    const metadata = useStore(form.store, (state) => state.values.metadata || [])

    const removeMetadata = (index: number) => {
      form.removeFieldValue('metadata', index)
    }

    const addMetadata = () => {
      form.pushFieldValue('metadata', {
        key: '',
        value: '',
        displayInInvoice: false,
      })
    }

    const displaySubfield = (id: string | undefined, index: number) => {
      return (
        <React.Fragment key={`metadata-item-${id || index}`}>
          <form.AppField name={`metadata[${index}].key`}>
            {(subField) => {
              const error = getMetadataError(subField.state.meta.errors)

              const hasCustomError = Object.keys(MetadataErrorsEnum).includes(error)

              const getTitle = () => {
                if (error === MetadataErrorsEnum.uniqueness) {
                  return translate('text_63fcc3218d35b9377840f5dd')
                }
                if (error === MetadataErrorsEnum.maxLength) {
                  return translate('text_63fcc3218d35b9377840f5d9', { max: 20 })
                }
                if (error === MetadataErrorsEnum.required) {
                  return translate('text_1764753433918x3icklnboak')
                }
                return undefined
              }

              return (
                <Tooltip
                  placement="top-end"
                  title={getTitle()}
                  disableHoverListener={!hasCustomError}
                >
                  <subField.TextInputField
                    silentError={!hasCustomError}
                    placeholder={translate('text_63fcc3218d35b9377840f5a7')}
                    displayErrorText={false}
                  />
                </Tooltip>
              )
            }}
          </form.AppField>
          <form.AppField name={`metadata[${index}].value`}>
            {(subField) => {
              const error = getMetadataError(subField.state.meta.errors)
              const hasCustomError = Object.keys(MetadataErrorsEnum).includes(error)

              const getTitle = () => {
                if (error === MetadataErrorsEnum.maxLength) {
                  return translate('text_63fcc3218d35b9377840f5e5', {
                    max: METADATA_VALUE_MAX_LENGTH_DEFAULT,
                  })
                }
                if (error === MetadataErrorsEnum.required) {
                  return translate('text_1764753433918nlsnvdnwjmo')
                }
                return undefined
              }

              return (
                <Tooltip
                  placement="top-end"
                  title={getTitle()}
                  disableHoverListener={!hasCustomError}
                >
                  <subField.TextInputField
                    silentError={!hasCustomError}
                    placeholder={translate('text_63fcc3218d35b9377840f5af')}
                    displayErrorText={false}
                  />
                </Tooltip>
              )
            }}
          </form.AppField>
          <form.AppField name={`metadata[${index}].displayInInvoice`}>
            {(subField) => <subField.SwitchField />}
          </form.AppField>
          <Tooltip
            className="flex items-center"
            placement="top-end"
            title={translate('text_63fcc3218d35b9377840f5e1')}
          >
            <Button
              variant="quaternary"
              size="small"
              icon="trash"
              onClick={() => removeMetadata(index)}
            />
          </Tooltip>
        </React.Fragment>
      )
    }

    return (
      <Accordion
        variant="borderless"
        summary={
          <div className="flex flex-col gap-2">
            <Typography variant="subhead1">{translate('text_63fcc3218d35b9377840f59b')}</Typography>
            <Typography variant="caption">{translate('text_1735655045719sl0z0pooptb')}</Typography>
          </div>
        }
      >
        <form.AppField name="metadata" mode="array">
          {(field) => {
            return (
              <div>
                {metadata.length > 0 && (
                  <div className={tw(gridClassName, 'mb-1 [&>*:nth-child(3)]:col-span-2')}>
                    <Typography variant="captionHl" color="grey700">
                      {translate('text_63fcc3218d35b9377840f5a3')}
                    </Typography>
                    <Typography variant="captionHl" color="grey700">
                      {translate('text_63fcc3218d35b9377840f5ab')}
                    </Typography>
                    <Typography variant="captionHl" color="grey700">
                      {translate('text_63fcc3218d35b9377840f5b3')}
                    </Typography>
                  </div>
                )}
                <div className={gridClassName}>
                  {field.state.value.map(({ id }, index) => displaySubfield(id, index))}
                </div>
                <Button
                  className={tw({ 'mt-4': metadata.length > 0 })}
                  startIcon="plus"
                  variant="inline"
                  disabled={(metadata?.length || 0) >= MAX_METADATA_COUNT}
                  onClick={addMetadata}
                  data-test="add-metadata-button"
                >
                  {translate('text_6405cac5c833dcf18cad0196')}
                </Button>
              </div>
            )
          }}
        </form.AppField>
      </Accordion>
    )
  },
})

export default MetadataAccordion
