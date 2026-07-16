import { FormikProps } from 'formik'
import _get from 'lodash/get'

import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { TextInputField } from '~/components/form'
import { MetadataErrorsEnum } from '~/formValidation/metadataSchema'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type SupportedFormFormat = {
  metadata?: Array<{
    key: string
    value: string
    localId?: string
  }>
}

type MetadataFormProps<T extends SupportedFormFormat = SupportedFormFormat> = {
  formikProps: FormikProps<T>
  maxMetadataCount?: number
  maxKeyLength?: number
  maxValueLength?: number
}

export const META_DATA_BUTTON_DATA_TEST_ID = 'add-metadata-button'

const MAX_METADATA_COUNT = 50
const METADATA_KEY_MAX_LENGTH_DEFAULT = 40
const METADATA_VALUE_MAX_LENGTH_DEFAULT = 255

const MetadataForm = <T extends SupportedFormFormat>({
  formikProps,
  maxMetadataCount = MAX_METADATA_COUNT,
  maxKeyLength = METADATA_KEY_MAX_LENGTH_DEFAULT,
  maxValueLength = METADATA_VALUE_MAX_LENGTH_DEFAULT,
}: MetadataFormProps<T>) => {
  const { translate } = useInternationalization()

  const removeMetadata = (index: number) => {
    const newMetadata = (formikProps.values.metadata || []).filter((_metadata, j) => {
      return j !== index
    })

    formikProps.setFieldValue('metadata', newMetadata)
  }

  const addMetadata = () => {
    formikProps.setFieldValue('metadata', [
      ...(formikProps.values.metadata || []),
      {
        key: '',
        value: '',
        localId: Date.now().toString(),
      },
    ])
  }

  const getKeyError = (index: number) => {
    const metadataItemKeyError: string =
      (_get(formikProps.errors, `metadata.${index}.key`) as string) ?? ''

    if (metadataItemKeyError === MetadataErrorsEnum.uniqueness) {
      return translate('text_63fcc3218d35b9377840f5dd')
    } else if (metadataItemKeyError === MetadataErrorsEnum.maxLength) {
      return translate('text_63fcc3218d35b9377840f5d9', { max: maxKeyLength })
    }

    return ''
  }

  const getValueError = (index: number) => {
    const metadataItemKeyError: string =
      (_get(formikProps.errors, `metadata.${index}.value`) as string) ?? ''

    if (metadataItemKeyError === MetadataErrorsEnum.maxLength) {
      return translate('text_63fcc3218d35b9377840f5e5', {
        max: maxValueLength,
      })
    }

    return ''
  }

  const gridClassName = 'grid grid-cols-[200px_1fr_24px] gap-x-3 '

  return (
    <>
      {!!formikProps?.values?.metadata?.length && (
        <div className="flex flex-col gap-y-6">
          {formikProps?.values?.metadata?.map((metadata, index) => {
            return (
              <div className="flex flex-col gap-y-1" key={`metadata-${metadata.localId || index}`}>
                {index === 0 && (
                  <div className={gridClassName}>
                    <Typography variant="captionHl" color="grey700">
                      {translate('text_63fcc3218d35b9377840f5a3')}
                    </Typography>
                    <Typography variant="captionHl" color="grey700">
                      {translate('text_63fcc3218d35b9377840f5ab')}
                    </Typography>
                  </div>
                )}

                <div className={gridClassName}>
                  <TextInputField
                    name={`metadata.${index}.key`}
                    placeholder={translate('text_63fcc3218d35b9377840f5a7')}
                    formikProps={formikProps}
                    error={getKeyError(index)}
                  />
                  <TextInputField
                    name={`metadata.${index}.value`}
                    placeholder={translate('text_63fcc3218d35b9377840f5af')}
                    formikProps={formikProps}
                    error={getValueError(index)}
                  />
                  {/* use mt-2 because we cannot align with flex since error messages are displayed under the input */}
                  <Tooltip
                    className="mt-2 flex"
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
                </div>
              </div>
            )
          })}
        </div>
      )}
      <div>
        <Button
          startIcon="plus"
          variant="inline"
          disabled={(formikProps?.values?.metadata?.length || 0) >= maxMetadataCount}
          onClick={() => addMetadata()}
          data-test={META_DATA_BUTTON_DATA_TEST_ID}
        >
          {translate('text_63fcc3218d35b9377840f5bb')}
        </Button>
      </div>
    </>
  )
}

export default MetadataForm
