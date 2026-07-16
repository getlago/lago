import InputAdornment from '@mui/material/InputAdornment'
import { useFormik } from 'formik'
import { useEffect, useRef, useState } from 'react'
import { array, boolean, number, object, string } from 'yup'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { WarningDialog, WarningDialogRef } from '~/components/designSystem/WarningDialog'
import { AmountInputField, ComboBoxField, TextInput, TextInputField } from '~/components/form'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import {
  DefaultCampaignDialog,
  DefaultCampaignDialogRef,
} from '~/components/settings/dunnings/DefaultCampaignDialog'
import {
  PreviewCampaignEmailDrawer,
  PreviewCampaignEmailDrawerRef,
} from '~/components/settings/dunnings/PreviewCampaignEmailDrawer'
import { FORM_ERRORS_ENUM } from '~/core/constants/form'
import { DUNNINGS_SETTINGS_ROUTE, useNavigate } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { scrollToTop } from '~/core/utils/domUtils'
import { updateNameAndMaybeCode } from '~/core/utils/updateNameAndMaybeCode'
import { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import {
  DunningCampaignFormInput,
  useCreateEditDunningCampaign,
} from '~/hooks/useCreateEditDunningCampaign'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { FormLoadingSkeleton } from '~/styles/mainObjectsForm'

const CreateDunning = () => {
  const {
    isEdition,
    errorCode,
    loading,
    onClose,
    onSave,
    campaign,
    hasPaymentProviderExcludingGoCardless,
  } = useCreateEditDunningCampaign()
  const { translate } = useInternationalization()
  const navigate = useNavigate()

  const defaultCampaignDialogRef = useRef<DefaultCampaignDialogRef>(null)
  const warningDirtyAttributesDialogRef = useRef<WarningDialogRef>(null)
  const previewCampaignEmailDrawerRef = useRef<PreviewCampaignEmailDrawerRef>(null)

  const { organization: { defaultCurrency } = {} } = useOrganizationInfos()

  useEffect(() => {
    if (errorCode === FORM_ERRORS_ENUM.existingCode) {
      formikProps.setFieldError('code', 'text_632a2d437e341dcc76817556')
      scrollToTop()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [errorCode])

  const formikProps = useFormik<DunningCampaignFormInput>({
    initialValues: {
      name: campaign?.name || '',
      code: campaign?.code || '',
      description: campaign?.description || '',
      thresholds: campaign?.thresholds
        ? campaign.thresholds.map((threshold) => ({
            ...threshold,
            amountCents: deserializeAmount(threshold.amountCents, threshold.currency),
          }))
        : [
            {
              currency: defaultCurrency ?? CurrencyEnum.Usd,
              amountCents: undefined,
            },
          ],
      daysBetweenAttempts: campaign?.daysBetweenAttempts
        ? String(campaign.daysBetweenAttempts)
        : '',
      maxAttempts: campaign?.maxAttempts ? String(campaign.maxAttempts) : '',
      bccEmails: campaign?.bccEmails?.join(',') || '',
      appliedToOrganization: campaign?.appliedToOrganization || false,
    },
    validationSchema: object().shape({
      name: string().required(''),
      code: string().required(''),
      description: string(),
      thresholds: array()
        .of(
          object().shape({
            currency: string().required(''),
            amountCents: string().required(''),
          }),
        )
        .min(1, '')
        .test((thresholds) => {
          const currencies = thresholds?.map((t) => t.currency)

          return new Set(currencies).size === currencies?.length
        })
        .required(''),
      daysBetweenAttempts: number().min(1, '').required(''),
      maxAttempts: number().min(1, '').required(''),
      appliedToOrganization: boolean().required(''),
      bccEmails: array()
        .transform((value) => value.split(',').map((v: string) => v.trim()))
        .of(string().email()),
    }),
    enableReinitialize: true,
    validateOnMount: true,
    onSubmit: onSave,
  })

  const [shouldDisplayDescription, setShouldDisplayDescription] = useState(
    !!formikProps.initialValues.description,
  )
  const [shouldDisplayBCCEmails, setShouldDisplayBCCEmails] = useState(
    !!formikProps.initialValues.bccEmails.length,
  )

  useEffect(() => {
    setShouldDisplayDescription(!!formikProps.initialValues.description)
    setShouldDisplayBCCEmails(!!formikProps.initialValues.bccEmails.length)
  }, [formikProps.initialValues])

  const onSubmit = () => {
    if (
      // If the appliedToOrganization field has changed and is now true, open the default campaign dialog
      formikProps.initialValues.appliedToOrganization !==
        formikProps.values.appliedToOrganization &&
      formikProps.values.appliedToOrganization === true
    ) {
      defaultCampaignDialogRef.current?.openDialog({
        type: 'setDefault',
        onConfirm: () => formikProps.submitForm(),
      })
    } else {
      formikProps.submitForm()
    }
  }

  return (
    <>
      <CenteredPage.Wrapper>
        <CenteredPage.Header>
          <Typography variant="bodyHl" color="textSecondary" noWrap>
            {translate(
              isEdition ? 'text_17322041874138xkertqxbqz' : 'text_17285840281865oxs4lxfs6j',
            )}
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
          {loading ? (
            <FormLoadingSkeleton id="create-dunning" />
          ) : (
            <>
              {isEdition && (
                <Alert type="warning">{translate('text_1732187313660ghhrj235mxg')}</Alert>
              )}

              <div className="not-last-child:mb-1">
                <Typography variant="headline" color="textSecondary">
                  {translate('text_1728584028187fg2ebhssz6r')}
                </Typography>
                <Typography variant="body">{translate('text_1728584028187st1bmr7wdw9')}</Typography>
              </div>

              <div className="flex flex-col gap-12 not-last-child:pb-12 not-last-child:shadow-b">
                <section className="not-last-child:mb-6">
                  <div className="not-last-child:mb-2">
                    <Typography variant="subhead1">
                      {translate('text_1728584028187on239g4adt5')}
                    </Typography>
                    <Typography variant="caption">
                      {translate('text_1728584028187im92nik4ff8')}
                    </Typography>
                  </div>
                  <div className="flex items-start gap-6 *:flex-1">
                    <TextInput
                      // eslint-disable-next-line jsx-a11y/no-autofocus
                      autoFocus
                      name="name"
                      value={formikProps.values.name}
                      onChange={(name) => {
                        updateNameAndMaybeCode({ name, formikProps })
                      }}
                      label={translate('text_6419c64eace749372fc72b0f')}
                      placeholder={translate('text_6584550dc4cec7adf861504f')}
                    />
                    <TextInputField
                      name="code"
                      beforeChangeFormatter="code"
                      formikProps={formikProps}
                      label={translate('text_62876e85e32e0300e1803127')}
                      placeholder={translate('text_6584550dc4cec7adf8615053')}
                    />
                  </div>
                  {shouldDisplayDescription ? (
                    <div className="flex items-center gap-2">
                      <TextInputField
                        className="flex-1"
                        name="description"
                        label={translate('text_623b42ff8ee4e000ba87d0c8')}
                        placeholder={translate('text_1728584028187uqs16ra27ef')}
                        rows="3"
                        multiline
                        formikProps={formikProps}
                      />

                      <Tooltip
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
                      startIcon="plus"
                      variant="inline"
                      onClick={() => setShouldDisplayDescription(true)}
                      data-test="show-description"
                    >
                      {translate('text_642d5eb2783a2ad10d670324')}
                    </Button>
                  )}
                </section>

                <section className="not-last-child:mb-6">
                  <div className="not-last-child:mb-2">
                    <Typography variant="subhead1">
                      {translate('text_1742392390147aoog6603wwy')}
                    </Typography>
                    <Typography variant="caption">
                      {translate('text_1742392390147fju3ihxmtin')}
                    </Typography>
                  </div>

                  <div className="flex flex-col gap-6">
                    {formikProps.values.thresholds.map((_threshold, index) => {
                      const key = `thresholds.${index}`

                      return (
                        <div key={key} className="flex flex-1 items-center gap-4">
                          <ComboBoxField
                            className="w-30"
                            name={`${key}.currency`}
                            formikProps={formikProps}
                            data={Object.values(CurrencyEnum).map((currency) => ({
                              label: currency,
                              value: currency,
                              disabled: formikProps.values.thresholds.some(
                                (localThreshold) => localThreshold.currency === currency,
                              ),
                            }))}
                            placeholder={translate('text_632c6e59b73f9a54d4c7224b')}
                            disableClearable
                          />
                          <AmountInputField
                            className="flex-1"
                            name={`${key}.amountCents`}
                            formikProps={formikProps}
                            currency={CurrencyEnum.Usd}
                            beforeChangeFormatter={['positiveNumber']}
                          />
                          {index > 0 && (
                            <Tooltip
                              placement="top-end"
                              title={translate('text_63aa085d28b8510cd46443ff')}
                            >
                              <Button
                                icon="trash"
                                variant="quaternary"
                                onClick={() => {
                                  const newThresholds = [...formikProps.values.thresholds]

                                  newThresholds.splice(index, 1)
                                  formikProps.setFieldValue('thresholds', newThresholds)
                                }}
                              />
                            </Tooltip>
                          )}
                        </div>
                      )
                    })}

                    <div>
                      <Button
                        startIcon="plus"
                        variant="inline"
                        onClick={() =>
                          formikProps.setFieldValue('thresholds', [
                            ...formikProps.values.thresholds,
                            { currency: undefined, amountCents: '' },
                          ])
                        }
                      >
                        {translate('text_1728584028187rmbbvaboadk')}
                      </Button>
                    </div>
                  </div>
                </section>

                <section className="not-last-child:mb-6">
                  <div className="not-last-child:mb-2">
                    <Typography variant="subhead1">
                      {translate('text_1742392390147pcg2p300roc')}
                    </Typography>
                    <Typography variant="caption">
                      <span className="mr-1">
                        {hasPaymentProviderExcludingGoCardless
                          ? translate('text_1728584028187l2wdjy4s5cs')
                          : translate('text_17291534666709ytr7mi4jjl')}
                      </span>
                      <button
                        className="h-auto p-0 text-blue-600 hover:underline focus:underline"
                        onClick={() => previewCampaignEmailDrawerRef.current?.openDrawer()}
                      >
                        {translate('text_1728584028187udjepvgj8ra')}
                      </button>
                    </Typography>
                  </div>

                  <TextInputField
                    name="daysBetweenAttempts"
                    formikProps={formikProps}
                    label={translate('text_1728584028187al65i47z3qn')}
                    placeholder="0"
                    beforeChangeFormatter={['positiveNumber']}
                    InputProps={{
                      endAdornment: (
                        <InputAdornment position="end">
                          {translate('text_638dc196fb209d551f3d814d')}
                        </InputAdornment>
                      ),
                    }}
                  />
                  <TextInputField
                    name="maxAttempts"
                    formikProps={formikProps}
                    label={translate('text_17285840281879mpfdrz2mmi')}
                    placeholder="0"
                    beforeChangeFormatter={['positiveNumber']}
                    InputProps={{
                      endAdornment: (
                        <InputAdornment position="end">
                          {translate('text_172858402818763zwy2u9e3t')}
                        </InputAdornment>
                      ),
                    }}
                  />
                  {shouldDisplayBCCEmails ? (
                    <div className="flex flex-1 items-center gap-4">
                      <TextInputField
                        name="bccEmails"
                        className="flex-1"
                        beforeChangeFormatter={['lowercase']}
                        formikProps={formikProps}
                        label={translate('text_1742392390147xtfe9hub59a')}
                        placeholder={translate('text_1742392390147xia24oyubb3')}
                        helperText={translate('text_1742392390147638s3zam327')}
                      />
                      <Tooltip
                        placement="top-end"
                        title={translate('text_63aa085d28b8510cd46443ff')}
                      >
                        <Button
                          icon="trash"
                          variant="quaternary"
                          onClick={() => {
                            formikProps.setFieldValue('bccEmails', '')
                            setShouldDisplayBCCEmails(false)
                          }}
                        />
                      </Tooltip>
                    </div>
                  ) : (
                    <Button
                      startIcon="plus"
                      variant="inline"
                      onClick={() => setShouldDisplayBCCEmails(true)}
                      data-test="show-bcc-emails"
                    >
                      {translate('text_1742392390147d9jizkapiou')}
                    </Button>
                  )}
                </section>
              </div>
            </>
          )}
        </CenteredPage.Container>

        <CenteredPage.StickyFooter>
          <Button
            variant="quaternary"
            onClick={() =>
              formikProps.dirty
                ? warningDirtyAttributesDialogRef.current?.openDialog()
                : navigate(DUNNINGS_SETTINGS_ROUTE)
            }
          >
            {translate('text_6411e6b530cb47007488b027')}
          </Button>
          <Button
            variant="primary"
            disabled={!formikProps.isValid || !formikProps.dirty}
            onClick={onSubmit}
          >
            {translate(
              isEdition ? 'text_17295436903260tlyb1gp1i7' : 'text_1742392390147u5hy5yetful',
            )}
          </Button>
        </CenteredPage.StickyFooter>
      </CenteredPage.Wrapper>

      <WarningDialog
        ref={warningDirtyAttributesDialogRef}
        title={translate('text_6244277fe0975300fe3fb940')}
        description={translate('text_6244277fe0975300fe3fb946')}
        continueText={translate('text_6244277fe0975300fe3fb94c')}
        onContinue={() => navigate(DUNNINGS_SETTINGS_ROUTE)}
      />
      <DefaultCampaignDialog ref={defaultCampaignDialogRef} />
      <PreviewCampaignEmailDrawer ref={previewCampaignEmailDrawerRef} />
    </>
  )
}

export default CreateDunning
