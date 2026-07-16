import { gql } from '@apollo/client'
import { useFormik } from 'formik'
import { useCallback, useEffect, useMemo, useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'
import { array, boolean, number, object, string } from 'yup'

import AlertThresholds, { isThresholdValueValid } from '~/components/alerts/Thresholds'
import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { WarningDialog, WarningDialogRef } from '~/components/designSystem/WarningDialog'
import { ComboBox, TextInput, TextInputField } from '~/components/form'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { useNavigate, WALLET_DETAILS_ROUTE } from '~/core/router'
import { serializeAmount } from '~/core/serializers/serializeAmount'
import { updateNameAndMaybeCode } from '~/core/utils/updateNameAndMaybeCode'
import {
  AlertTypeEnum,
  CreateCustomerWalletAlertInput,
  CurrencyEnum,
  LagoApiError,
  ThresholdInput,
  useCreateWalletAlertMutation,
  useGetWalletAlertsQuery,
  useGetWalletAlertToEditQuery,
  useGetWalletDetailsQuery,
  useUpdateWalletAlertMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { sortAndFormatThresholds } from '~/pages/AlertForm'
import { WalletDetailsTabsOptionsEnum } from '~/pages/wallet/WalletDetails'
import { FormLoadingSkeleton } from '~/styles/mainObjectsForm'

gql`
  query getWalletAlertToEdit($id: ID!) {
    walletAlert(id: $id) {
      id
      alertType
      walletId
      code
      name
      thresholds {
        code
        recurring
        value
      }
    }
  }

  mutation createWalletAlert($input: CreateCustomerWalletAlertInput!) {
    createCustomerWalletAlert(input: $input) {
      id
    }
  }

  mutation updateWalletAlert($input: UpdateCustomerWalletAlertInput!) {
    updateCustomerWalletAlert(input: $input) {
      id
    }
  }
`

const WalletAlertForm = () => {
  const { alertId = '', customerId = '', walletId = '' } = useParams()
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const warningDirtyAttributesDialogRef = useRef<WarningDialogRef>(null)
  const isEdition = !!alertId

  const { data, loading } = useGetWalletDetailsQuery({
    variables: { walletId: walletId as string },
    skip: !walletId,
  })

  const { data: existingAlertsData, loading: existingAlertsLoading } = useGetWalletAlertsQuery({
    variables: {
      walletId: walletId as string,
    },
    skip: !walletId,
  })

  const {
    data: alertData,
    loading: alertLoading,
    error: alertError,
  } = useGetWalletAlertToEditQuery({
    variables: { id: alertId },
    skip: !isEdition,
    context: { silentErrorCodes: [LagoApiError.NotFound] },
  })

  const isLoading = loading || alertLoading || existingAlertsLoading

  const existingAlertsTypes = useMemo(() => {
    return existingAlertsData?.walletAlerts?.collection?.map((al) => al.alertType)
  }, [existingAlertsData?.walletAlerts?.collection])

  const existingAlert = alertData?.walletAlert
  const currency = data?.wallet?.currency || CurrencyEnum.Usd

  const isCreditsAlert = (alertType: AlertTypeEnum) =>
    alertType === AlertTypeEnum.WalletCreditsBalance ||
    alertType === AlertTypeEnum.WalletCreditsOngoingBalance

  const isOngoingAlert = (alertType: AlertTypeEnum) =>
    alertType === AlertTypeEnum.WalletOngoingBalanceAmount ||
    alertType === AlertTypeEnum.WalletCreditsOngoingBalance

  const onLeave = useCallback(
    ({ replace = false }: { replace?: boolean } = {}) => {
      if (!!customerId) {
        navigate(
          generatePath(WALLET_DETAILS_ROUTE, {
            customerId,
            walletId,
            tab: WalletDetailsTabsOptionsEnum.alerts,
          }),
          { replace },
        )
      }
    },
    [customerId, navigate, walletId],
  )

  // Redirect to alerts list if alert is not found (e.g., deleted while on edit page)
  useEffect(() => {
    if (isEdition && !alertLoading && hasDefinedGQLError('NotFound', alertError)) {
      addToast({
        severity: 'info',
        translateKey: 'text_1737477631498hwm4np3kbnd',
      })
      // Use replace to prevent back button from returning to this deleted alert page
      onLeave({ replace: true })
    }
  }, [isEdition, alertLoading, alertError, onLeave])

  const [updateAlert, { error: updateError }] = useUpdateWalletAlertMutation({
    onCompleted({ updateCustomerWalletAlert }) {
      if (!!updateCustomerWalletAlert?.id) {
        addToast({
          severity: 'success',
          translateKey: 'text_1746623860224qwhtxyuophr',
        })

        onLeave()
      }
    },
  })

  const [createAlert, { error: createError }] = useCreateWalletAlertMutation({
    onCompleted({ createCustomerWalletAlert }) {
      if (!!createCustomerWalletAlert?.id) {
        addToast({
          severity: 'success',
          translateKey: 'text_1746611635509ov7jepx55bz',
        })

        onLeave()
      }
    },
  })

  const formikProps = useFormik<CreateCustomerWalletAlertInput>({
    initialValues: {
      walletId: data?.wallet?.id || '',
      name: existingAlert?.name || '',
      code: existingAlert?.code || '',
      alertType: existingAlert?.alertType || ('' as AlertTypeEnum),
      thresholds: !!existingAlert?.thresholds?.length
        ? sortAndFormatThresholds(
            existingAlert?.thresholds,
            currency,
            isCreditsAlert(existingAlert?.alertType),
          )
        : [
            {
              code: '',
              recurring: false,
              value: '',
            },
          ],
    },
    validationSchema: object().shape({
      name: string(),
      code: string().required(''),
      alertType: string().required(''),
      thresholds: array()
        .of(
          object().shape({
            code: string(),
            recurring: boolean().required(''),
            value: number().required(''),
          }),
        )
        .nullable(),
    }),
    enableReinitialize: true,
    validateOnMount: true,
    onSubmit: async ({ alertType, thresholds, walletId: currentWalletId, ...values }) => {
      const thresholdValue = (threshold: ThresholdInput) => {
        if (isCreditsAlert(alertType)) {
          return threshold.value.split('.')[0]
        }

        return String(serializeAmount(threshold.value, currency))
      }

      const formattedThresholds = thresholds?.map((threshold) => ({
        ...threshold,
        value: thresholdValue(threshold),
      }))

      // Edition
      if (!!existingAlert?.id) {
        await updateAlert({
          variables: {
            input: {
              ...values,
              id: existingAlert.id,
              thresholds: formattedThresholds || undefined,
            },
          },
        })
      } else {
        await createAlert({
          variables: {
            input: {
              ...values,
              alertType,
              walletId: currentWalletId,
              thresholds: formattedThresholds || undefined,
            },
          },
        })
      }
    },
  })

  useEffect(() => {
    if (hasDefinedGQLError('ValueAlreadyExist', createError || updateError)) {
      formikProps.setFieldError('code', 'text_632a2d437e341dcc76817556')
      const rootElement = document.getElementById('root')

      if (!rootElement) return
      rootElement.scrollTo({ top: 0 })
    }

    return undefined
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [createError, formikProps.setFieldError, updateError])

  const hasAnyNonRecurringThresholdError = useMemo(() => {
    const localNonRecurringThresholds = formikProps.values.thresholds.filter(
      (threshold) => !threshold.recurring,
    )

    return localNonRecurringThresholds.some((threshold, i) =>
      isThresholdValueValid(i, threshold.value, localNonRecurringThresholds, true),
    )
  }, [formikProps.values.thresholds])

  const setThresholds = (thresholds: ThresholdInput[]) => {
    formikProps.setFieldValue('thresholds', thresholds)
  }

  const setThresholdValue = ({
    index,
    key,
    newValue,
  }: {
    index: number
    key: keyof ThresholdInput
    newValue: unknown
  }) => {
    formikProps.setFieldValue(`thresholds.${index}.${key}`, newValue)
  }

  const defaultTypesData = useMemo(
    () => [
      {
        label: translate('text_1773051593209b2tulsrwgoq'),
        value: AlertTypeEnum.WalletCreditsBalance,
      },
      {
        label: translate('text_1773051593209u4yacfcm339'),
        value: AlertTypeEnum.WalletCreditsOngoingBalance,
      },
      {
        label: translate('text_17730515932099j2rzezwwf0'),
        value: AlertTypeEnum.WalletBalanceAmount,
      },
      {
        label: translate('text_1773051593209gg3667wtxse'),
        value: AlertTypeEnum.WalletOngoingBalanceAmount,
      },
    ],
    [translate],
  )

  const comboboxData = useMemo(() => {
    return defaultTypesData?.filter((item) => !existingAlertsTypes?.includes(item.value))
  }, [defaultTypesData, existingAlertsTypes])

  return (
    <>
      <CenteredPage.Wrapper>
        <CenteredPage.Header>
          <div className="flex gap-3">
            <Typography variant="bodyHl" color="textSecondary" noWrap>
              {translate(
                isEdition ? 'text_1773051593208zapkd7kjz1d' : 'text_1773051593208nq2x0gbp83t',
              )}
            </Typography>
          </div>

          <Button
            variant="quaternary"
            icon="close"
            onClick={() =>
              formikProps.dirty ? warningDirtyAttributesDialogRef.current?.openDialog() : onLeave()
            }
          />
        </CenteredPage.Header>

        <CenteredPage.Container>
          {isLoading && <FormLoadingSkeleton id="create-wallet-alert" />}

          {!isLoading && (
            <>
              <div className="not-last-child:mb-1">
                <Typography variant="headline" color="grey700">
                  {translate('text_1773051593208ufsg18ai0y0')}
                </Typography>

                <Typography variant="body" color="grey600">
                  {translate('text_17465238490260r2325jwada')}
                </Typography>
              </div>

              <div className="flex flex-col gap-12">
                <section className="pb-12 shadow-b not-last-child:mb-6">
                  <div className="not-last-child:mb-2">
                    <Typography variant="subhead1">
                      {translate('text_1746629929876zz4937djyc8')}
                    </Typography>
                    <Typography variant="caption">
                      {translate('text_1746629929876gdgxt1v86eq')}
                    </Typography>
                  </div>
                  <div className="flex gap-6 *:flex-1">
                    <TextInput
                      name="name"
                      label={translate('text_1773063868176dy5v3kvne2l')}
                      placeholder={translate('text_62876e85e32e0300e1803121')}
                      value={formikProps.values.name || ''}
                      onChange={(name) => {
                        updateNameAndMaybeCode({ name, formikProps })
                      }}
                    />
                    <TextInputField
                      name="code"
                      label={translate('text_62876e85e32e0300e1803127')}
                      placeholder={translate('text_623b42ff8ee4e000ba87d0c4')}
                      formikProps={formikProps}
                      error={formikProps.errors.code}
                    />
                  </div>
                </section>

                <section className="not-last-child:mb-6">
                  <div className="not-last-child:mb-2">
                    <Typography variant="subhead1">
                      {translate('text_17466299298762alw9zr25tb')}
                    </Typography>
                    <Typography variant="caption">
                      {translate('text_1746631350477wjvnr6ty57q')}
                    </Typography>
                  </div>
                  <div className="flex flex-col gap-6 *:flex-1">
                    <ComboBox
                      name="alertType"
                      label={translate('text_1746631350478jqk347d5dy4')}
                      placeholder={translate('text_1746631350478bwa1swfpwky')}
                      disabled={isEdition}
                      disableClearable={isEdition}
                      value={formikProps.values.alertType}
                      data={comboboxData}
                      onChange={(value) => {
                        const newFormikValues = {
                          ...formikProps.values,
                          alertType: value as AlertTypeEnum,
                        }

                        formikProps.setValues(newFormikValues)
                      }}
                    />

                    {formikProps?.values?.alertType && (
                      <AlertThresholds
                        thresholds={formikProps.values.thresholds}
                        setThresholds={setThresholds}
                        setThresholdValue={setThresholdValue}
                        currency={currency}
                        shouldHandleUnits={isCreditsAlert(formikProps.values.alertType)}
                        unitsLabel={translate('text_62d18855b22699e5cf55f889')}
                        unitsTitle={translate('text_1773063868176jh122suh1lx')}
                        reversedThreshold={true}
                        allowNegativeValues={isOngoingAlert(formikProps.values.alertType)}
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
            size="large"
            onClick={() =>
              formikProps.dirty ? warningDirtyAttributesDialogRef.current?.openDialog() : onLeave()
            }
          >
            {translate('text_6411e6b530cb47007488b027')}
          </Button>
          <Button
            variant="primary"
            size="large"
            disabled={
              !formikProps.isValid ||
              !formikProps.dirty ||
              isLoading ||
              hasAnyNonRecurringThresholdError
            }
            onClick={formikProps.submitForm}
          >
            {translate(
              isEdition ? 'text_17432414198706rdwf76ek3u' : 'text_1747917472538el8fg31n3i8',
            )}
          </Button>
        </CenteredPage.StickyFooter>
      </CenteredPage.Wrapper>

      <WarningDialog
        ref={warningDirtyAttributesDialogRef}
        title={translate('text_6244277fe0975300fe3fb940')}
        description={translate('text_1746623860224gh7o1exyjch')}
        continueText={translate('text_6244277fe0975300fe3fb94c')}
        onContinue={onLeave}
      />
    </>
  )
}

export default WalletAlertForm
