import { useFormik } from 'formik'
import { useEffect, useRef, useState } from 'react'
import { generatePath, useParams } from 'react-router-dom'
import { number, object, string } from 'yup'

import { AddOnCodeSnippet } from '~/components/addOns/AddOnCodeSnippet'
import { AddOnFormInput } from '~/components/addOns/types'
import { Button } from '~/components/designSystem/Button'
import { Card } from '~/components/designSystem/Card'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { WarningDialog, WarningDialogRef } from '~/components/designSystem/WarningDialog'
import { AmountInputField, ComboBoxField, TextInput, TextInputField } from '~/components/form'
import { TaxesSelectorSection } from '~/components/taxes/TaxesSelectorSection'
import { FORM_ERRORS_ENUM, SEARCH_TAX_INPUT_FOR_ADD_ON_CLASSNAME } from '~/core/constants/form'
import { ADD_ON_DETAILS_ROUTE, ADD_ONS_ROUTE, useNavigate } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { scrollToTop } from '~/core/utils/domUtils'
import { updateNameAndMaybeCode } from '~/core/utils/updateNameAndMaybeCode'
import { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCreateEditAddOn } from '~/hooks/useCreateEditAddOn'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { PageHeader } from '~/styles'
import { Main, Side, Subtitle, Title } from '~/styles/mainObjectsForm'

const CreateAddOn = () => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { organization } = useOrganizationInfos()
  const { addOnId } = useParams()
  const { isEdition, loading, addOn, errorCode, onSave } = useCreateEditAddOn()
  const warningDialogRef = useRef<WarningDialogRef>(null)

  const onCloseRedirection = () => {
    if (isEdition && !!addOnId) {
      return navigate(generatePath(ADD_ON_DETAILS_ROUTE, { addOnId }))
    }

    return navigate(ADD_ONS_ROUTE)
  }

  const formikProps = useFormik<AddOnFormInput>({
    initialValues: {
      name: addOn?.name || '',
      code: addOn?.code || '',
      description: addOn?.description || '',
      amountCents: addOn?.amountCents
        ? String(
            deserializeAmount(
              addOn?.amountCents,
              addOn?.amountCurrency || organization?.defaultCurrency,
            ),
          )
        : addOn?.amountCents || undefined,
      amountCurrency: addOn?.amountCurrency || organization?.defaultCurrency || CurrencyEnum.Usd,
      taxes: addOn?.taxes || [],
    },
    validationSchema: object().shape({
      name: string().required(''),
      code: string().required(''),
      amountCents: number().min(0.01, 'text_62978ebe99054a011fc189e0').required(''),
      amountCurrency: string().required(''),
    }),
    enableReinitialize: true,
    validateOnMount: true,
    onSubmit: onSave,
  })

  const [shouldDisplayDescription, setShouldDisplayDescription] = useState<boolean>(
    !!formikProps.initialValues.description,
  )

  useEffect(() => {
    setShouldDisplayDescription(!!formikProps.initialValues.description)
  }, [formikProps.initialValues.description])

  useEffect(() => {
    if (errorCode === FORM_ERRORS_ENUM.existingCode) {
      formikProps.setFieldError('code', 'text_632a2d437e341dcc76817556')
      scrollToTop()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [errorCode])

  return (
    <div>
      <PageHeader.Wrapper>
        <Typography variant="bodyHl" color="textSecondary" noWrap>
          {translate(isEdition ? 'text_629728388c4d2300e2d37fc2' : 'text_629728388c4d2300e2d37fbc')}
        </Typography>
        <Button
          variant="quaternary"
          icon="close"
          onClick={() => {
            if (formikProps.dirty) return warningDialogRef.current?.openDialog()

            onCloseRedirection()
          }}
        />
      </PageHeader.Wrapper>
      <div className="min-height-minus-nav flex">
        <Main>
          <div>
            {loading ? (
              <>
                <div className="px-8">
                  <Skeleton variant="text" className="mb-5 w-70" />
                  <Skeleton variant="text" className="mb-4" />
                  <Skeleton variant="text" className="w-30" />
                </div>

                {[0, 1].map((skeletonCard) => (
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
                      isEdition ? 'text_629728388c4d2300e2d38041' : 'text_629728388c4d2300e2d3803d',
                    )}
                  </Title>
                  <Subtitle>
                    {translate(
                      isEdition ? 'text_629728388c4d2300e2d38065' : 'text_629728388c4d2300e2d38061',
                    )}
                  </Subtitle>
                </div>

                <Card>
                  <Typography variant="subhead1">
                    {translate('text_629728388c4d2300e2d38079')}
                  </Typography>

                  <div className="flex flex-wrap gap-3">
                    <TextInput
                      className="min-w-[110px] flex-1"
                      name="name"
                      label={translate('text_629728388c4d2300e2d38091')}
                      placeholder={translate('text_629728388c4d2300e2d380a5')}
                      // eslint-disable-next-line jsx-a11y/no-autofocus
                      autoFocus
                      value={formikProps.values.name}
                      onChange={(name) => {
                        updateNameAndMaybeCode({ name, formikProps })
                      }}
                    />
                    <TextInputField
                      className="min-w-[110px] flex-1"
                      name="code"
                      beforeChangeFormatter="code"
                      label={translate('text_629728388c4d2300e2d380b7')}
                      placeholder={translate('text_629728388c4d2300e2d380d9')}
                      formikProps={formikProps}
                      infoText={translate('text_629778b2a517d100c19bc524')}
                    />
                  </div>

                  {shouldDisplayDescription ? (
                    <div className="flex items-center">
                      <TextInputField
                        className="mr-3 flex-1"
                        multiline
                        name="description"
                        label={translate('text_629728388c4d2300e2d380f1')}
                        placeholder={translate('text_629728388c4d2300e2d38103')}
                        rows="3"
                        formikProps={formikProps}
                      />
                      <Tooltip
                        className="mt-6"
                        placement="top-end"
                        title={translate('text_63aa085d28b8510cd46443ff')}
                      >
                        <Button
                          icon="trash"
                          variant="quaternary"
                          onClick={() => {
                            formikProps.setFieldValue('description', '')
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
                      {translate('text_642d5eb2783a2ad10d670324')}
                    </Button>
                  )}
                </Card>

                <Card>
                  <Typography variant="subhead1">
                    {translate('text_629728388c4d2300e2d38117')}
                  </Typography>

                  <div className="flex flex-row items-start gap-3">
                    <AmountInputField
                      className="flex-1"
                      name="amountCents"
                      currency={formikProps.values.amountCurrency || CurrencyEnum.Usd}
                      beforeChangeFormatter={['positiveNumber']}
                      label={translate('text_629728388c4d2300e2d3812d')}
                      formikProps={formikProps}
                    />
                    <ComboBoxField
                      className="mt-7 max-w-30"
                      name="amountCurrency"
                      data={Object.values(CurrencyEnum).map((currencyType) => ({
                        value: currencyType,
                      }))}
                      disableClearable
                      formikProps={formikProps}
                    />
                  </div>

                  <TaxesSelectorSection
                    title={translate('text_1760729707267seik64l67k8')}
                    taxes={formikProps?.values?.taxes || []}
                    comboboxSelector={SEARCH_TAX_INPUT_FOR_ADD_ON_CLASSNAME}
                    onUpdate={(newTaxArray) => {
                      formikProps.setFieldValue('taxes', newTaxArray)
                    }}
                  />

                  {/* {!!formikProps?.values?.taxes?.length && (
                    <div>
                      <Typography className="mb-1" variant="captionHl" color="grey700">
                        {translate('text_64be910fba8ef9208686a8e3')}
                      </Typography>
                      <div
                        className="flex flex-wrap items-center gap-3"
                        data-test="tax-chip-wrapper"
                      >
                        {formikProps?.values?.taxes?.map(({ id, name, rate }) => (
                          <Chip
                            key={id}
                            label={`${name} (${rate}%)`}
                            type="secondary"
                            size="medium"
                            deleteIcon="trash"
                            icon="percentage"
                            deleteIconLabel={translate('text_63aa085d28b8510cd46443ff')}
                            onDelete={() => {
                              const newTaxedArray =
                                formikProps?.values?.taxes?.filter((tax) => tax.id !== id) || []

                              formikProps.setFieldValue('taxes', newTaxedArray)
                            }}
                          />
                        ))}
                      </div>
                    </div>
                  )}

                  {shouldDisplayTaxesInput ? (
                    <div>
                      {!formikProps?.values?.taxes?.length && (
                        <Typography className="mb-1" variant="captionHl" color="grey700">
                          {translate('text_64be910fba8ef9208686a8e3')}
                        </Typography>
                      )}
                      <div className="flex items-center gap-3">
                        <ComboBox
                          containerClassName="flex-1"
                          className={SEARCH_TAX_INPUT_FOR_ADD_ON_CLASSNAME}
                          data={taxesDataForCombobox}
                          searchQuery={getTaxes}
                          loading={taxesLoading}
                          placeholder={translate('text_64be910fba8ef9208686a8e7')}
                          emptyText={translate('text_64be91fd0678965126e5657b')}
                          onChange={(newTaxId) => {
                            const previousTaxes = [...(formikProps?.values?.taxes || [])]
                            const newTaxObject = taxesData?.taxes?.collection?.find(
                              (t) => t.id === newTaxId,
                            )

                            formikProps.setFieldValue('taxes', [...previousTaxes, newTaxObject])
                            setShouldDisplayTaxesInput(false)
                          }}
                        />

                        <Tooltip
                          placement="top-end"
                          title={translate('text_63aa085d28b8510cd46443ff')}
                        >
                          <Button
                            icon="trash"
                            variant="quaternary"
                            onClick={() => {
                              setShouldDisplayTaxesInput(false)
                            }}
                          />
                        </Tooltip>
                      </div>
                    </div>
                  ) : (
                    <Button
                      className="self-start"
                      startIcon="plus"
                      variant="inline"
                      onClick={() => {
                        setShouldDisplayTaxesInput(true)

                        scrollToAndClickElement({
                          selector: `.${SEARCH_TAX_INPUT_FOR_ADD_ON_CLASSNAME} .${MUI_INPUT_BASE_ROOT_CLASSNAME}`,
                        })
                      }}
                      data-test="show-add-taxes"
                    >
                      {translate('text_64be910fba8ef9208686a8c9')}
                    </Button>
                  )} */}
                </Card>

                <div className="px-6 pb-20">
                  <Button
                    disabled={!formikProps.isValid || !formikProps.dirty}
                    fullWidth
                    size="large"
                    onClick={formikProps.submitForm}
                    data-test="submit"
                  >
                    {translate(
                      isEdition ? 'text_629728388c4d2300e2d38170' : 'text_629728388c4d2300e2d38179',
                    )}
                  </Button>
                </div>
              </>
            )}
          </div>
        </Main>
        <Side>
          <AddOnCodeSnippet loading={loading} addOn={formikProps.values} />
        </Side>
      </div>
      <WarningDialog
        ref={warningDialogRef}
        title={translate('text_665deda4babaf700d603ea13')}
        description={translate('text_665dedd557dc3c00c62eb83d')}
        continueText={translate('text_645388d5bdbd7b00abffa033')}
        onContinue={onCloseRedirection}
      />
    </div>
  )
}

export default CreateAddOn
