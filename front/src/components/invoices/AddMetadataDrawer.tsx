import { gql } from '@apollo/client'
import { useFormik } from 'formik'
import _get from 'lodash/get'
import React, { forwardRef, RefObject } from 'react'
import { object } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Card } from '~/components/designSystem/Card'
import { Drawer, DrawerRef } from '~/components/designSystem/Drawer'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { TextInputField } from '~/components/form'
import { addToast } from '~/core/apolloClient'
import { MetadataErrorsEnum, metadataSchema } from '~/formValidation/metadataSchema'
import {
  UpdateInvoiceInput,
  useGetInvoiceMetadataForEditionQuery,
  useUpdateInvoiceMetadataMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { DrawerContent, DrawerSubmitButton, DrawerTitle } from '~/styles'
import { tw } from '~/styles/utils'

const MAX_METADATA_COUNT = 5
const METADATA_VALUE_MAX_LENGTH = 255

gql`
  fragment InvoiceMetadatasForMetadataDrawer on Invoice {
    id
    metadata {
      id
      key
      value
    }
  }

  mutation updateInvoiceMetadata($input: UpdateInvoiceInput!) {
    updateInvoice(input: $input) {
      id
      ...InvoiceMetadatasForMetadataDrawer
    }
  }

  query getInvoiceMetadataForEdition($id: ID!) {
    invoice(id: $id) {
      id
      ...InvoiceMetadatasForMetadataDrawer
    }
  }
`

export type AddMetadataDrawerRef = DrawerRef

interface AddMetadataDrawerProps {
  invoiceId: string
}

export const AddMetadataDrawer = forwardRef<DrawerRef, AddMetadataDrawerProps>(
  ({ invoiceId }, ref) => {
    const { translate } = useInternationalization()

    const { data } = useGetInvoiceMetadataForEditionQuery({
      variables: {
        id: invoiceId || '',
      },
      skip: !invoiceId,
    })

    const isEdition = !!data?.invoice?.metadata?.length

    const [updateInvoiceMetadata] = useUpdateInvoiceMetadataMutation({
      onCompleted({ updateInvoice }) {
        if (updateInvoice?.id) {
          addToast({
            message: translate(
              isEdition ? 'text_6405cac5c833dcf18cad01fb' : 'text_6405cac5c833dcf18cad0204',
            ),
            severity: 'success',
          })
        }
      },
    })
    const formikProps = useFormik<Omit<UpdateInvoiceInput, 'id'>>({
      initialValues: {
        metadata: data?.invoice?.metadata ?? undefined,
      },
      validationSchema: object().shape({
        metadata: metadataSchema({ valueMaxLength: METADATA_VALUE_MAX_LENGTH }),
      }),
      validateOnMount: true,
      enableReinitialize: true,
      onSubmit: async (values) => {
        await updateInvoiceMetadata({
          variables: {
            input: {
              id: data?.invoice?.id as string,
              ...values,
            },
          },
        })
        ;(ref as unknown as RefObject<DrawerRef>)?.current?.closeDrawer()
      },
    })

    const metadataGridClassname = 'grid grid-cols-[200px_1fr_24px] gap-x-6 gap-y-3'

    return (
      <Drawer
        ref={ref}
        title={translate(
          isEdition ? 'text_6405cac5c833dcf18cacff2a' : 'text_6405cac5c833dcf18cacff2c',
        )}
        onClose={() => {
          formikProps.resetForm()
          formikProps.validateForm()
        }}
      >
        <DrawerContent>
          <DrawerTitle>
            <Typography variant="headline">
              {translate(
                isEdition ? 'text_6405cac5c833dcf18cacff6c' : 'text_6405cac5c833dcf18cacff32',
              )}
            </Typography>
            <Typography>{translate('text_6405cac5c833dcf18cacff38')}</Typography>
          </DrawerTitle>

          <Card className="items-start">
            <Typography variant="subhead1">{translate('text_6405cac5c833dcf18cacff3e')}</Typography>

            {!!formikProps?.values?.metadata?.length && (
              <div>
                <div className={tw(metadataGridClassname, 'mb-1 [&>*:nth-child(2)]:col-span-2')}>
                  <Typography variant="captionHl" color="grey700">
                    {translate('text_6405cac5c833dcf18cacff66')}
                  </Typography>
                  <Typography variant="captionHl" color="grey700">
                    {translate('text_6405cac5c833dcf18cacff7c')}
                  </Typography>
                </div>
                <div className={metadataGridClassname}>
                  {formikProps?.values?.metadata?.map((m, i) => {
                    const metadataItemKeyError: string =
                      _get(formikProps.errors, `metadata.${i}.key`) || ''
                    const metadataItemValueError: string =
                      _get(formikProps.errors, `metadata.${i}.value`) || ''
                    const hasCustomKeyError =
                      Object.keys(MetadataErrorsEnum).includes(metadataItemKeyError)
                    const hasCustomValueError =
                      Object.keys(MetadataErrorsEnum).includes(metadataItemValueError)

                    let keyErrorTitle: string | undefined = undefined

                    if (metadataItemKeyError === MetadataErrorsEnum.uniqueness) {
                      keyErrorTitle = translate('text_63fcc3218d35b9377840f5dd')
                    } else if (metadataItemKeyError === MetadataErrorsEnum.maxLength) {
                      keyErrorTitle = translate('text_63fcc3218d35b9377840f5d9', { max: 20 })
                    }

                    return (
                      <React.Fragment key={`metadata-item-${m.id || i}`}>
                        <Tooltip
                          placement="top-end"
                          title={keyErrorTitle}
                          disableHoverListener={!hasCustomKeyError}
                        >
                          <TextInputField
                            name={`metadata.${i}.key`}
                            silentError={!hasCustomKeyError}
                            placeholder={translate('text_63fcc3218d35b9377840f5a7')}
                            formikProps={formikProps}
                            displayErrorText={false}
                          />
                        </Tooltip>
                        <Tooltip
                          placement="top-end"
                          title={
                            metadataItemValueError === MetadataErrorsEnum.maxLength
                              ? translate('text_63fcc3218d35b9377840f5e5', {
                                  max: METADATA_VALUE_MAX_LENGTH,
                                })
                              : undefined
                          }
                          disableHoverListener={!hasCustomValueError}
                        >
                          <TextInputField
                            name={`metadata.${i}.value`}
                            silentError={!hasCustomValueError}
                            placeholder={translate('text_63fcc3218d35b9377840f5af')}
                            formikProps={formikProps}
                            displayErrorText={false}
                          />
                        </Tooltip>
                        <Tooltip
                          className="flex items-center"
                          placement="top-end"
                          title={translate('text_63fcc3218d35b9377840f5e1')}
                        >
                          <Button
                            variant="quaternary"
                            size="small"
                            icon="trash"
                            onClick={() => {
                              formikProps.setFieldValue('metadata', [
                                ...(formikProps.values.metadata || []).filter((metadata, j) => {
                                  return j !== i
                                }),
                              ])
                            }}
                          />
                        </Tooltip>
                      </React.Fragment>
                    )
                  })}
                </div>
              </div>
            )}
            <Button
              startIcon="plus"
              variant="inline"
              disabled={(formikProps?.values?.metadata?.length || 0) >= MAX_METADATA_COUNT}
              onClick={() =>
                formikProps.setFieldValue('metadata', [
                  ...(formikProps.values.metadata || []),
                  {
                    key: '',
                    value: '',
                  },
                ])
              }
              data-test="add-fixed-fee"
            >
              {translate('text_6405cac5c833dcf18cacff44')}
            </Button>
          </Card>

          <DrawerSubmitButton>
            <Button
              size="large"
              disabled={
                !formikProps.isValid ||
                (isEdition && !formikProps.dirty) ||
                (!formikProps.dirty && !formikProps.values.metadata?.length)
              }
              loading={formikProps.isSubmitting}
              fullWidth
              data-test="submit"
              onClick={formikProps.submitForm}
            >
              {translate(
                isEdition ? 'text_6405cac5c833dcf18cacffec' : 'text_6405cac5c833dcf18cacff4a',
              )}
            </Button>
          </DrawerSubmitButton>
        </DrawerContent>
      </Drawer>
    )
  },
)

AddMetadataDrawer.displayName = 'AddMetadataDrawer'
