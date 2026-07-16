import { useFormik } from 'formik'
import { useEffect } from 'react'

import { Button } from '~/components/designSystem/Button'
import { FiltersFormValues } from '~/components/designSystem/Filters/types'
import { formatMetadataFilter, parseMetadataFilter } from '~/components/designSystem/Filters/utils'
import { Typography } from '~/components/designSystem/Typography'
import { TextInputField } from '~/components/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type FiltersItemMetadataProps = {
  value: FiltersFormValues['filters'][0]['value']
  setFilterValue: (value: string) => void
}

const MAX_METADATA_COUNT = 5

export const FiltersItemMetadata = ({ value = '', setFilterValue }: FiltersItemMetadataProps) => {
  const { translate } = useInternationalization()

  const initialMetadata = parseMetadataFilter(value)

  const formikProps = useFormik({
    initialValues: {
      metadata: initialMetadata.length ? initialMetadata : [{ key: '', value: '' }],
    },
    validateOnMount: true,
    enableReinitialize: true,
    onSubmit: () => {},
  })

  useEffect(() => {
    const { metadata } = formikProps.values

    setFilterValue(formatMetadataFilter(metadata))

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [formikProps.values.metadata])

  return (
    <div className="flex flex-col gap-4">
      {formikProps.values.metadata.map((_metadata, i) => (
        <div
          className="grid grid-cols-[minmax(30px,max-content)_1fr_minmax(5px,max-content)_1fr_24px] items-center gap-2 lg:gap-3"
          key={i}
        >
          {i === 0 ? (
            <Typography variant="body" color="grey700">
              {translate('text_66ab42d4ece7e6b7078993d0')}
            </Typography>
          ) : (
            <Typography variant="body" color="grey700">
              {translate('text_65f8472df7593301061e27d6').toLowerCase()}
            </Typography>
          )}
          <TextInputField
            name={`metadata.${i}.key`}
            placeholder={translate('text_63fcc3218d35b9377840f5a7')}
            formikProps={formikProps}
          />
          <Typography className="text-grey-700">=</Typography>
          <TextInputField
            name={`metadata.${i}.value`}
            placeholder={translate('text_63fcc3218d35b9377840f5af')}
            formikProps={formikProps}
          />
          <Button
            icon="trash"
            variant="quaternary"
            size="small"
            disabled={i === 0 && formikProps.values.metadata.length === 1}
            onClick={() =>
              formikProps.setFieldValue(
                'metadata',
                formikProps.values.metadata.filter((_, index) => index !== i),
              )
            }
          />
        </div>
      ))}
      <Button
        startIcon="plus"
        variant="inline"
        fitContent
        disabled={formikProps.values.metadata.length >= MAX_METADATA_COUNT}
        onClick={() =>
          formikProps.setFieldValue('metadata', [
            ...formikProps.values.metadata,
            {
              key: '',
              value: '',
            },
          ])
        }
        data-test="add-metadata-button"
      >
        {translate('text_63fcc3218d35b9377840f5bb')}
      </Button>
    </div>
  )
}
