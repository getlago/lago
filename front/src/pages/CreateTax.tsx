import InputAdornment from '@mui/material/InputAdornment'
import { revalidateLogic, useStore } from '@tanstack/react-form'
import { useEffect, useRef, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Card } from '~/components/designSystem/Card'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { WarningDialog, WarningDialogRef } from '~/components/designSystem/WarningDialog'
import NameAndCodeGroup from '~/components/form/NameAndCodeGroup/NameAndCodeGroup'
import { TaxCodeSnippet } from '~/components/taxes/TaxCodeSnippet'
import { TaxFormInput } from '~/components/taxes/types'
import { FORM_ERRORS_ENUM } from '~/core/constants/form'
import { scrollToTop } from '~/core/utils/domUtils'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'
import { useCreateEditTax } from '~/hooks/useCreateEditTax'
import { PageHeader } from '~/styles'
import { Main, Side, Subtitle, Title } from '~/styles/mainObjectsForm'

import { taxFormSchema, TaxFormValues } from './createTax/validationSchema'

export const CREATE_TAX_FORM_ID = 'create-tax-form'
export const CREATE_TAX_CLOSE_BUTTON_TEST_ID = 'create-tax-close-button'
export const CREATE_TAX_DESCRIPTION_DELETE_TEST_ID = 'create-tax-description-delete'

const CreateTaxRate = () => {
  const { isEdition, errorCode, loading, onClose, onSave, tax } = useCreateEditTax()
  const leavingNotSavedChargesWarningDialogRef = useRef<WarningDialogRef>(null)
  const savingAppliedTaxRateWarningDialogRef = useRef<WarningDialogRef>(null)
  const saveAfterConfirmRef = useRef<() => Promise<void>>(async () => {})
  const { translate } = useInternationalization()

  const form = useAppForm({
    defaultValues: {
      code: tax?.code || '',
      description: tax?.description || '',
      name: tax?.name || '',
      rate: isNaN(Number(tax?.rate)) ? '' : String(tax?.rate),
    } as TaxFormValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: taxFormSchema,
    },
    onSubmit: async ({ value }) => {
      if ((tax?.customersCount || 0) > 0) {
        saveAfterConfirmRef.current = async () => {
          await onSave(value as unknown as TaxFormInput)
        }
        savingAppliedTaxRateWarningDialogRef.current?.openDialog()
      } else {
        await onSave(value as unknown as TaxFormInput)
      }
    },
  })

  useEffect(() => {
    if (tax) {
      form.reset({
        code: tax.code || '',
        description: tax.description || '',
        name: tax.name || '',
        rate: isNaN(Number(tax?.rate)) ? '' : String(tax?.rate),
      })
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tax?.id])

  const [shouldDisplayDescription, setShouldDisplayDescription] = useState<boolean>(
    !!tax?.description,
  )

  useEffect(() => {
    setShouldDisplayDescription(!!tax?.description)
  }, [tax?.description])

  useEffect(() => {
    if (errorCode === FORM_ERRORS_ENUM.existingCode) {
      form.setFieldMeta('code', (meta) => ({
        ...meta,
        errorMap: {
          ...meta.errorMap,
          onDynamic: { message: 'text_632a2d437e341dcc76817556' },
        },
      }))
      scrollToTop()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [errorCode])

  const codeValue = useStore(form.store, (state) => state.values.code)

  useEffect(() => {
    if (errorCode === FORM_ERRORS_ENUM.existingCode) {
      form.setFieldMeta('code', (meta) => ({
        ...meta,
        errorMap: { ...meta.errorMap, onDynamic: undefined },
      }))
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [codeValue])

  const formValues = useStore(form.store, (state) => state.values)
  const isDirty = useStore(form.store, (state) => state.isDirty)

  const handleFormSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    form.handleSubmit()
  }

  return (
    <div>
      <PageHeader.Wrapper>
        <Typography variant="bodyHl" color="textSecondary" noWrap>
          {translate(isEdition ? 'text_645bb193927b375079d289b5' : 'text_645bb193927b375079d289af')}
        </Typography>
        <Button
          variant="quaternary"
          icon="close"
          data-test={CREATE_TAX_CLOSE_BUTTON_TEST_ID}
          onClick={() =>
            isDirty ? leavingNotSavedChargesWarningDialogRef.current?.openDialog() : onClose()
          }
        />
      </PageHeader.Wrapper>
      <form
        id={CREATE_TAX_FORM_ID}
        className="min-height-minus-nav flex"
        onSubmit={handleFormSubmit}
      >
        <Main>
          <div>
            {loading && !tax ? (
              <>
                <div className="px-8">
                  <Skeleton variant="text" className="mb-5 w-70" />
                  <Skeleton variant="text" className="mb-4" />
                  <Skeleton variant="text" className="w-30" />
                </div>

                {[0, 1, 2].map((skeletonCard) => (
                  <Card key={`skeleton-${skeletonCard}`}>
                    <Skeleton variant="text" className="w-70" />
                    <Skeleton variant="text" />
                    <Skeleton variant="text" className="w-30" />
                  </Card>
                ))}
              </>
            ) : (
              <>
                <div>
                  <Title variant="headline">
                    {translate(
                      isEdition ? 'text_645bb193927b375079d28a0d' : 'text_645bb193927b375079d28a51',
                    )}
                  </Title>
                  <Subtitle>
                    {translate(
                      isEdition ? 'text_645bb193927b375079d28a17' : 'text_645bb193927b375079d28a71',
                    )}
                  </Subtitle>
                </div>

                <Card>
                  <Typography variant="subhead1">
                    {translate('text_645bb193927b375079d28a91')}
                  </Typography>

                  <NameAndCodeGroup
                    form={form}
                    fields={{ name: 'name', code: 'code' }}
                    disableAutoGenerateCode={isEdition || tax?.autoGenerated}
                    nameProps={{
                      autoFocus: true,
                      label: translate('text_645bb193927b375079d28ab1'),
                      placeholder: translate('text_645bb193927b375079d28ace'),
                      className: 'flex-1',
                    }}
                    codeProps={{
                      label: translate('text_645bb193927b375079d28aea'),
                      placeholder: translate('text_645bb193927b375079d28b02'),
                      infoText: translate('text_645bb193927b375079d28b7a'),
                      className: 'flex-1',
                    }}
                  />

                  {shouldDisplayDescription ? (
                    <div className="flex items-center">
                      <form.AppField name="description">
                        {(field) => (
                          <field.TextInputField
                            className="mr-3 flex-1"
                            // eslint-disable-next-line jsx-a11y/no-autofocus
                            autoFocus
                            multiline
                            label={translate('text_645bb193927b375079d28b22')}
                            placeholder={translate('text_645bb193927b375079d28b36')}
                            rows="3"
                          />
                        )}
                      </form.AppField>
                      <Tooltip
                        className="mt-6"
                        placement="top-end"
                        title={translate('text_63aa085d28b8510cd46443ff')}
                      >
                        <Button
                          icon="trash"
                          variant="quaternary"
                          data-test={CREATE_TAX_DESCRIPTION_DELETE_TEST_ID}
                          onClick={() => {
                            form.setFieldValue('description', '')
                            setShouldDisplayDescription(false)
                          }}
                        />
                      </Tooltip>
                    </div>
                  ) : (
                    <Button
                      className="self-start"
                      startIcon="plus"
                      variant="inline"
                      onClick={() => setShouldDisplayDescription(true)}
                      data-test="show-description"
                    >
                      {translate('text_645bb193927b375079d28b16')}
                    </Button>
                  )}

                  <form.AppField name="rate">
                    {(field) => (
                      <field.TextInputField
                        disabled={tax?.autoGenerated}
                        label={translate('text_645bb193927b375079d28b2c')}
                        beforeChangeFormatter={['positiveNumber', 'quadDecimal']}
                        placeholder={translate('text_632d68358f1fedc68eed3e86')}
                        InputProps={{
                          endAdornment: (
                            <InputAdornment position="end">
                              {translate('text_62a0b7107afa2700a65ef70a')}
                            </InputAdornment>
                          ),
                        }}
                      />
                    )}
                  </form.AppField>
                </Card>

                <div className="px-6 pb-20">
                  <form.AppForm>
                    <form.SubmitButton
                      disabled={isEdition && !isDirty}
                      fullWidth
                      size="large"
                      dataTest="submit"
                    >
                      {translate(
                        isEdition
                          ? 'text_645bb193927b375079d28ab7'
                          : 'text_645bb193927b375079d28b8e',
                      )}
                    </form.SubmitButton>
                  </form.AppForm>
                </div>
              </>
            )}
          </div>
        </Main>
        <Side>
          <TaxCodeSnippet
            loading={loading}
            tax={formValues as unknown as TaxFormInput}
            isEdition={isEdition}
            initialTaxCode={tax?.code}
          />
        </Side>
      </form>
      <WarningDialog
        ref={leavingNotSavedChargesWarningDialogRef}
        title={translate('text_645bb193927b375079d289cb')}
        description={translate('text_645bb193927b375079d289d9')}
        continueText={translate('text_645bb193927b375079d289f9')}
        onContinue={onClose}
      />
      <WarningDialog
        mode="info"
        ref={savingAppliedTaxRateWarningDialogRef}
        title={translate('text_6464a12047f2dd00affa924f', {
          name: tax?.name,
        })}
        description={translate(
          'text_6464a12047f2dd00affa9250',
          {
            customersCount: tax?.customersCount,
          },
          tax?.customersCount,
        )}
        continueText={translate('text_6464a12047f2dd00affa9252')}
        onContinue={() => saveAfterConfirmRef.current()}
      />
    </div>
  )
}

export default CreateTaxRate
