import { useFormik } from 'formik'
import { useEffect, useRef } from 'react'
import { object, string } from 'yup'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { WarningDialog, WarningDialogRef } from '~/components/designSystem/WarningDialog'
import { ComboBoxField, SwitchField, TextInput, TextInputField } from '~/components/form'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { LogoPicker } from '~/components/LogoPicker'
import { DOCUMENTATION_EINVOICING } from '~/core/constants/externalUrls'
import { FORM_ERRORS_ENUM } from '~/core/constants/form'
import { countryDataForCombobox } from '~/core/formats/countryDataForCombobox'
import { scrollToTop } from '~/core/utils/domUtils'
import { updateNameAndMaybeCode } from '~/core/utils/updateNameAndMaybeCode'
import { CreateBillingEntityInput, UpdateBillingEntityInput } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import useCreateEditBillingEntity from '~/hooks/useCreateEditBillingEntity'
import { MANDATORY_EINVOICING_COUNTRIES } from '~/pages/settings/BillingEntity/const'
import { FormLoadingSkeleton } from '~/styles/mainObjectsForm'

const BillingEntityCreateEdit = () => {
  const { translate } = useInternationalization()

  const { isEdition, errorCode, loading, onClose, onSave, billingEntity } =
    useCreateEditBillingEntity()

  const warningDirtyAttributesDialogRef = useRef<WarningDialogRef>(null)

  useEffect(() => {
    if (errorCode === FORM_ERRORS_ENUM.existingCode) {
      formikProps.setFieldError('code', 'text_632a2d437e341dcc76817556')
      scrollToTop()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [errorCode])

  type BillingEntityFormInput = CreateBillingEntityInput | UpdateBillingEntityInput

  const formikProps = useFormik<BillingEntityFormInput & { logo: string | null | undefined }>({
    initialValues: {
      name: billingEntity?.name || '',
      code: billingEntity?.code || '',
      legalName: billingEntity?.legalName || '',
      legalNumber: billingEntity?.legalNumber || '',
      taxIdentificationNumber: billingEntity?.taxIdentificationNumber || '',
      email: billingEntity?.email || '',
      phone: billingEntity?.phone || '',
      addressLine1: billingEntity?.addressLine1 || '',
      addressLine2: billingEntity?.addressLine2 || '',
      zipcode: billingEntity?.zipcode || '',
      city: billingEntity?.city || '',
      state: billingEntity?.state || '',
      country: billingEntity?.country || undefined,
      logo: undefined,
      einvoicing: billingEntity?.einvoicing || false,
    },
    validationSchema: object().shape({
      code: string().required(''),
      name: string().required(''),
    }),
    enableReinitialize: true,
    validateOnMount: true,
    onSubmit: async (values) => {
      await onSave({
        ...values,
        phone: values.phone || null,
      })
    },
  })

  useEffect(() => {
    if (
      formikProps.values.country &&
      MANDATORY_EINVOICING_COUNTRIES.includes(formikProps.values.country) &&
      !formikProps.values.einvoicing
    ) {
      formikProps.setFieldValue('einvoicing', false)
    }

    if (
      !formikProps.values.country ||
      !MANDATORY_EINVOICING_COUNTRIES.includes(formikProps.values.country)
    ) {
      formikProps.setFieldValue('einvoicing', undefined)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [formikProps.values.country])

  const canDisplayEinvoicingField =
    formikProps.values.country &&
    MANDATORY_EINVOICING_COUNTRIES.includes(formikProps.values.country)

  return (
    <>
      <CenteredPage.Wrapper>
        <CenteredPage.Header>
          <Typography variant="bodyHl" color="textSecondary" noWrap>
            {isEdition && translate('text_1743077296189h6w5gkxmgwz')}
            {!isEdition && translate('text_17423672666602uggxpe1r0v')}
          </Typography>

          <Button
            variant="quaternary"
            icon="close"
            onClick={() =>
              formikProps.dirty ? warningDirtyAttributesDialogRef.current?.openDialog() : onClose()
            }
          />
        </CenteredPage.Header>

        <CenteredPage.Container>
          {loading && <FormLoadingSkeleton id="create-billing-entity" />}

          {!loading && (
            <>
              <div className="not-last-child:mb-1">
                <Typography variant="headline" color="textSecondary">
                  {translate('text_1743077296189ms0shds6g53')}
                </Typography>
                <Typography variant="body">{translate('text_1743077296189ji809eyi90y')}</Typography>
              </div>

              <div className="flex flex-col gap-12 not-last-child:pb-12 not-last-child:shadow-b">
                <section className="not-last-child:mb-6">
                  <div className="not-last-child:mb-2">
                    <Typography variant="subhead1">
                      {translate('text_1743077296189sv3omf8cjep')}
                    </Typography>
                    <Typography variant="caption">
                      {translate('text_1743077296189q2ukwvbtf5y')}
                    </Typography>
                  </div>
                  <div className="flex items-start gap-6 *:flex-1">
                    <TextInput
                      // eslint-disable-next-line jsx-a11y/no-autofocus
                      autoFocus
                      name="name"
                      value={formikProps.values.name || ''}
                      onChange={(name) => {
                        updateNameAndMaybeCode({ name, formikProps })
                      }}
                      label={translate('text_6419c64eace749372fc72b0f')}
                      placeholder={translate('text_6584550dc4cec7adf861504f')}
                    />

                    <TextInputField
                      name="code"
                      disabled={!!isEdition}
                      beforeChangeFormatter="code"
                      formikProps={formikProps}
                      label={translate('text_62876e85e32e0300e1803127')}
                      placeholder={translate('text_6584550dc4cec7adf8615053')}
                    />
                  </div>
                </section>

                <section className="not-last-child:mb-6">
                  <div className="not-last-child:mb-2">
                    <Typography variant="subhead1">
                      {translate('text_17430772961890sgj8ku8lmp')}
                    </Typography>
                    <Typography variant="caption">
                      {translate('text_1743077296189mme3pwm3xxu')}
                    </Typography>
                  </div>

                  <div className="mb-8 flex flex-col gap-6">
                    <LogoPicker
                      logoValue={formikProps.values.logo}
                      onChange={(value) => formikProps.setFieldValue('logo', value)}
                      logoUrl={billingEntity?.logoUrl}
                      name={billingEntity?.name}
                    />

                    <TextInputField
                      name="legalName"
                      label={translate('text_62ab2d0396dd6b0361614d40')}
                      placeholder={translate('text_62ab2d0396dd6b0361614d48')}
                      formikProps={formikProps}
                    />

                    <TextInputField
                      name="legalNumber"
                      label={translate('text_62ab2d0396dd6b0361614d50')}
                      placeholder={translate('text_62ab2d0396dd6b0361614d58')}
                      formikProps={formikProps}
                    />

                    <TextInputField
                      name="taxIdentificationNumber"
                      label={translate('text_648053ee819b60364c675d05')}
                      placeholder={translate('text_648053ee819b60364c675d0b')}
                      formikProps={formikProps}
                    />

                    <TextInputField
                      name="email"
                      beforeChangeFormatter={['lowercase']}
                      label={translate('text_62ab2d0396dd6b0361614d60')}
                      placeholder={translate('text_62ab2d0396dd6b0361614d68')}
                      formikProps={formikProps}
                    />

                    <TextInputField
                      name="phone"
                      label={translate('text_626c0c09812bbc00e4c59e0d')}
                      placeholder={translate('text_626c0c09812bbc00e4c59e0f')}
                      formikProps={formikProps}
                    />

                    <div className="flex flex-col gap-4">
                      <TextInputField
                        name="addressLine1"
                        label={translate('text_62ab2d0396dd6b0361614d70')}
                        placeholder={translate('text_62ab2d0396dd6b0361614d78')}
                        formikProps={formikProps}
                      />
                      <TextInputField
                        name="addressLine2"
                        placeholder={translate('text_62ab2d0396dd6b0361614d80')}
                        formikProps={formikProps}
                      />
                      <TextInputField
                        name="zipcode"
                        placeholder={translate('text_62ab2d0396dd6b0361614d88')}
                        formikProps={formikProps}
                      />
                      <TextInputField
                        name="city"
                        placeholder={translate('text_62ab2d0396dd6b0361614d90')}
                        formikProps={formikProps}
                      />
                      <TextInputField
                        name="state"
                        placeholder={translate('text_62ab2d0396dd6b0361614d98')}
                        formikProps={formikProps}
                      />
                      <ComboBoxField
                        data={countryDataForCombobox}
                        name="country"
                        placeholder={translate('text_62ab2d0396dd6b0361614da0')}
                        formikProps={formikProps}
                        PopperProps={{ displayInDialog: true }}
                      />
                    </div>
                  </div>
                </section>

                <section className="not-last-child:mb-6">
                  <div className="not-last-child:mb-2">
                    <Typography variant="subhead1">
                      {translate('text_1760101157939jviogsjfcsn')}
                    </Typography>
                    <Typography variant="caption">
                      {translate('text_1760101157939mnmlyzbp7ao')}
                    </Typography>
                  </div>
                  <div className="mb-8 flex flex-col gap-6">
                    {!canDisplayEinvoicingField ? (
                      <Alert type="warning">
                        <Typography
                          className="word-break-word"
                          color="textSecondary"
                          html={translate('text_176010285376748i8jr0rwn2', {
                            href: DOCUMENTATION_EINVOICING,
                          })}
                        />
                      </Alert>
                    ) : (
                      <SwitchField
                        formikProps={formikProps}
                        name="einvoicing"
                        label={translate('text_1760103938878g88itu3cdah')}
                        subLabel={translate('text_1760103938878069h2vcfis3')}
                      />
                    )}
                  </div>
                </section>
              </div>
            </>
          )}
        </CenteredPage.Container>

        <CenteredPage.StickyFooter>
          <Button
            variant="quaternary"
            onClick={() =>
              formikProps.dirty ? warningDirtyAttributesDialogRef.current?.openDialog() : onClose()
            }
          >
            {translate('text_6411e6b530cb47007488b027')}
          </Button>

          <Button
            variant="primary"
            disabled={!formikProps.isValid || !formikProps.dirty}
            onClick={formikProps.submitForm}
          >
            {isEdition && translate('text_17432414198706rdwf76ek3u')}

            {!isEdition && translate('text_174324141987010zhlfvyidj')}
          </Button>
        </CenteredPage.StickyFooter>
      </CenteredPage.Wrapper>

      <WarningDialog
        ref={warningDirtyAttributesDialogRef}
        title={translate('text_6244277fe0975300fe3fb940')}
        description={translate('text_6244277fe0975300fe3fb946')}
        continueText={translate('text_6244277fe0975300fe3fb94c')}
        onContinue={() => onClose()}
      />
    </>
  )
}

export default BillingEntityCreateEdit
