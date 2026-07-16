import { gql } from '@apollo/client'
import { useFormik } from 'formik'
import { useCallback, useId, useMemo, useRef, useState } from 'react'
import { generatePath, useParams } from 'react-router-dom'
import { array, object, string } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { ChargeTable } from '~/components/designSystem/Table/ChargeTable'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { WarningDialog, WarningDialogRef } from '~/components/designSystem/WarningDialog'
import { ComboBox, ComboBoxField, ComboboxItem } from '~/components/form'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { PrivilegeValueInputComponent } from '~/components/plans/PrivilegeValueInputComponent'
import { addToast } from '~/core/apolloClient'
import {
  MUI_INPUT_BASE_ROOT_CLASSNAME,
  SEARCH_SUBSCRIPTION_ENTITLEMENT_PRIVILEGE_SELECT_OPTIONS_INPUT_CLASSNAME,
} from '~/core/constants/form'
import { CustomerSubscriptionDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE,
  PLAN_SUBSCRIPTION_DETAILS_ROUTE,
  useNavigate,
} from '~/core/router'
import { scrollToAndClickElement } from '~/core/utils/domUtils'
import {
  CreateOrUpdateSubscriptionEntitlementInput,
  PrivilegeValueTypeEnum,
  SubscriptionEntitlement,
  useCreateOrUpdateSubscriptionEntitlementMutation,
  useGetSubscriptionDataForEntitlementFormQuery,
  useGetSubscriptionEntitlementToEditQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { FormLoadingSkeleton } from '~/styles/mainObjectsForm'

gql`
  query getSubscriptionDataForEntitlementForm($subscriptionId: ID!) {
    subscriptionEntitlements(subscriptionId: $subscriptionId) {
      collection {
        code
        name
        privileges {
          code
          name
          value
          valueType
          config {
            selectOptions
          }
        }
      }
    }

    features(limit: 1000) {
      collection {
        code
        name
        privileges {
          code
          name
          valueType
          config {
            selectOptions
          }
        }
      }
    }
  }
  query getSubscriptionEntitlementToEdit($featureCode: String!, $subscriptionId: ID!) {
    subscriptionEntitlement(featureCode: $featureCode, subscriptionId: $subscriptionId) {
      code
      name
      privileges {
        code
        name
        value
        valueType
        config {
          selectOptions
        }
      }
    }
  }

  mutation createOrUpdateSubscriptionEntitlement(
    $input: CreateOrUpdateSubscriptionEntitlementInput!
  ) {
    createOrUpdateSubscriptionEntitlement(input: $input) {
      code
    }
  }
`

const SubscriptionEntitlementForm = () => {
  const { entitlementCode = '', customerId = '', planId = '', subscriptionId = '' } = useParams()
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const componentId = useId()
  const warningDirtyAttributesDialogRef = useRef<WarningDialogRef>(null)
  const [displayAddPrivilegeInput, setDisplayAddPrivilegeInput] = useState(false)

  const isEdition = !!entitlementCode

  const { data: subscriptionData, loading: subscriptionLoading } =
    useGetSubscriptionDataForEntitlementFormQuery({
      variables: { subscriptionId },
    })

  const { data: entitlementData, loading: entitlementLoading } =
    useGetSubscriptionEntitlementToEditQuery({
      variables: { featureCode: entitlementCode, subscriptionId },
      skip: !isEdition || !entitlementCode || !subscriptionId,
    })

  const isLoading = entitlementLoading

  const existingEntitlement = entitlementData?.subscriptionEntitlement

  const privilegeSearchClassName = useMemo(() => {
    // Replace all colons with dashes to make the class name valid for querySelector
    const usableComponentId = componentId.replace(/:/g, '-')

    return `${SEARCH_SUBSCRIPTION_ENTITLEMENT_PRIVILEGE_SELECT_OPTIONS_INPUT_CLASSNAME}-${usableComponentId}`
  }, [componentId])

  const onLeave = useCallback(() => {
    if (!!customerId) {
      navigate(
        generatePath(CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE, {
          customerId,
          subscriptionId,
          tab: CustomerSubscriptionDetailsTabsOptionsEnum.entitlements,
        }),
      )
    } else if (!!planId) {
      navigate(
        generatePath(PLAN_SUBSCRIPTION_DETAILS_ROUTE, {
          planId,
          subscriptionId,
          tab: CustomerSubscriptionDetailsTabsOptionsEnum.entitlements,
        }),
      )
    }
  }, [customerId, navigate, planId, subscriptionId])

  const [createOrUpdateEntitlement] = useCreateOrUpdateSubscriptionEntitlementMutation({
    onCompleted({ createOrUpdateSubscriptionEntitlement }) {
      if (!!createOrUpdateSubscriptionEntitlement?.code) {
        addToast({
          severity: 'success',
          translateKey: isEdition
            ? 'text_17558572087888xlvutbxm98'
            : 'text_17558572087886chozdb8kiz',
        })

        onLeave()
      }
    },
  })

  const formikProps = useFormik<Pick<SubscriptionEntitlement, 'code' | 'privileges'>>({
    initialValues: {
      code: existingEntitlement?.code || '',
      privileges:
        existingEntitlement?.privileges?.map((privilege) => ({
          value: privilege?.value || '',
          name: privilege?.name || '',
          code: privilege?.code || '',
          valueType: privilege?.valueType || PrivilegeValueTypeEnum.Boolean,
          config: privilege?.config || undefined,
        })) || [],
    },
    validationSchema: object().shape({
      code: string().required(''),
      privileges: array()
        .of(
          object().shape({
            code: string().required(''),
            value: string().required(''),
            valueType: string().required(''),
            config: object().nullable(),
          }),
        )
        .nullable(),
    }),
    enableReinitialize: true,
    validateOnMount: true,
    onSubmit: async ({ code, ...values }) => {
      const input = {
        subscriptionId,
        entitlement: {
          ...values,
          featureCode: code || '',
          privileges: values.privileges?.map((privilege) => ({
            ...privilege,
            privilegeCode: privilege.code || '',
            value: privilege.value || '',
            // Reset UI fields cause BE does not accept them
            config: undefined,
            name: undefined,
            code: undefined,
            valueType: undefined,
          })),
        },
      } satisfies CreateOrUpdateSubscriptionEntitlementInput

      await createOrUpdateEntitlement({
        variables: {
          input,
        },
      })
    },
  })

  const featuresListComboboxData = useMemo(() => {
    if (!subscriptionData) return []

    const { subscriptionEntitlements, features } = subscriptionData

    return (features?.collection || []).map((item) => {
      const { code, name } = item

      return {
        label: `${name} (${code})`,
        value: code,
        labelNode: (
          <ComboboxItem>
            <Typography variant="body" color="grey700" noWrap>
              {name}
            </Typography>
            <Typography variant="caption" color="grey600" noWrap>
              {code}
            </Typography>
          </ComboboxItem>
        ),
        disabled: subscriptionEntitlements?.collection?.some(
          (entitlement) => entitlement.code === code,
        ),
      }
    })
  }, [subscriptionData])

  const privilegesListComboBoxData = useMemo(() => {
    if (!subscriptionData?.features?.collection?.length) return []

    const feature = subscriptionData.features.collection.find(
      (f) => f.code === formikProps.values.code,
    )

    if (!feature) return []

    return (feature?.privileges || []).map((privilege) => ({
      value: privilege.code,
      label: `${privilege.name} (${privilege.code})`,
      labelNode: (
        <ComboboxItem>
          <Typography variant="body" color="grey700" noWrap>
            {privilege.name}
          </Typography>
          <Typography variant="caption" color="grey600" noWrap>
            {privilege.code}
          </Typography>
        </ComboboxItem>
      ),
      disabled: formikProps.values.privileges?.some(
        (privilegeForUpdate) => privilegeForUpdate.code === privilege.code,
      ),
    }))
  }, [
    formikProps.values.code,
    formikProps.values.privileges,
    subscriptionData?.features?.collection,
  ])

  return (
    <>
      <CenteredPage.Wrapper>
        <CenteredPage.Header>
          <div className="flex gap-2">
            <Typography variant="bodyHl" color="textSecondary" noWrap>
              {translate(
                isEdition ? 'text_17561254890571tcj63iu382' : 'text_1753864223060devvklm7vk0',
              )}
            </Typography>
            <Chip size="small" label={translate('text_65d8d71a640c5400917f8a13')} />
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
          {isLoading && <FormLoadingSkeleton id="create-alert" />}
          {!isLoading && (
            <>
              <div className="not-last-child:mb-1">
                <Typography variant="headline" color="grey700">
                  {translate('text_1756125489057x892tvlnat0')}
                </Typography>
                <Typography variant="body" color="grey600">
                  {translate('text_17538642230602p03937fj0f')}
                </Typography>
              </div>

              <div className="flex flex-col gap-12">
                <section className="not-last-child:mb-6">
                  <div className="not-last-child:mb-2">
                    <Typography variant="subhead1">
                      {translate('text_17561254890572l8l58nidzn')}
                    </Typography>
                    <Typography variant="caption">
                      {translate('text_1756125489057oq6le0rt7mw')}
                    </Typography>
                  </div>
                  <div className="flex flex-col gap-12 *:flex-1">
                    <ComboBoxField
                      name="code"
                      disableClearable={isEdition}
                      placeholder={translate('text_1753864223060h6i2e7303eb')}
                      disabled={isEdition}
                      loading={subscriptionLoading}
                      data={featuresListComboboxData}
                      formikProps={formikProps}
                    />

                    {!!formikProps.values.privileges.length && (
                      <div className="-mx-4 -my-1 w-full overflow-auto px-4 py-1">
                        <ChargeTable
                          className="w-full"
                          name={`feature-entitlement-${formikProps.values.code}-privilege-table`}
                          data={formikProps.values.privileges || []}
                          deleteTooltipContent={translate('text_17538642230608t3xmlgja96')}
                          onDeleteRow={(row) => {
                            formikProps.setFieldValue(
                              'privileges',
                              formikProps.values.privileges?.filter(
                                (privilegeForUpdate) => privilegeForUpdate.code !== row.code,
                              ),
                            )
                          }}
                          columns={[
                            {
                              size: 300,
                              title: (
                                <Typography variant="captionHl" className="px-4">
                                  {translate('text_175386422306019wldpp8h5q')}
                                </Typography>
                              ),
                              content: (row) => (
                                <Typography variant="body" color="grey700" className="px-4">
                                  {row.name || row.code}
                                </Typography>
                              ),
                            },
                            {
                              size: 300,
                              title: (
                                <Typography variant="captionHl" className="px-4">
                                  {translate('text_63fcc3218d35b9377840f5ab')}
                                </Typography>
                              ),
                              content: (row) => {
                                return (
                                  <PrivilegeValueInputComponent
                                    translate={translate}
                                    valueType={row.valueType}
                                    value={row.value || ''}
                                    config={row.config}
                                    onChange={(value) => {
                                      formikProps.setFieldValue(
                                        'privileges',
                                        formikProps.values.privileges?.map((privilegeForUpdate) =>
                                          privilegeForUpdate.code === row.code
                                            ? {
                                                ...privilegeForUpdate,
                                                value,
                                              }
                                            : privilegeForUpdate,
                                        ),
                                      )
                                    }}
                                  />
                                )
                              },
                            },
                          ]}
                        />
                      </div>
                    )}

                    {displayAddPrivilegeInput ? (
                      <div className="flex w-full items-center gap-3">
                        <ComboBox
                          disableClearable
                          containerClassName="w-full"
                          placeholder={translate('text_1753864223060yk3svyv4dpr')}
                          loading={subscriptionLoading}
                          data={privilegesListComboBoxData}
                          className={privilegeSearchClassName}
                          onChange={(selectedPrivilege) => {
                            if (!selectedPrivilege) return

                            const selectedPrivilegeFullData =
                              subscriptionData?.features?.collection.find(
                                (feature) => feature.code === formikProps.values.code,
                              )

                            if (!selectedPrivilegeFullData) {
                              setDisplayAddPrivilegeInput(false)
                              return
                            }

                            const selectedPrivilegeFullDataPrivilege =
                              selectedPrivilegeFullData.privileges.find(
                                (privilege) => privilege.code === selectedPrivilege,
                              )

                            if (!selectedPrivilegeFullDataPrivilege) {
                              setDisplayAddPrivilegeInput(false)
                              return
                            }

                            formikProps.setFieldValue('privileges', [
                              ...(formikProps.values.privileges || []),
                              {
                                code: selectedPrivilegeFullDataPrivilege.code,
                                config: selectedPrivilegeFullDataPrivilege.config || undefined,
                                name: selectedPrivilegeFullDataPrivilege.name,
                                value: '',
                                valueType: selectedPrivilegeFullDataPrivilege.valueType,
                              },
                            ])

                            setDisplayAddPrivilegeInput(false)
                          }}
                        />
                        <Tooltip
                          placement="top-end"
                          title={translate('text_63aa085d28b8510cd46443ff')}
                        >
                          <Button
                            variant="quaternary"
                            icon="trash"
                            onClick={() => {
                              setDisplayAddPrivilegeInput(false)
                            }}
                          />
                        </Tooltip>
                      </div>
                    ) : (
                      <Tooltip
                        title={translate('text_1756125489057qfgsq8im2b2')}
                        placement="top-start"
                        disableHoverListener={!!formikProps.values.code}
                      >
                        <Button
                          align="left"
                          variant="inline"
                          startIcon="plus"
                          disabled={!formikProps.values.code}
                          onClick={() => {
                            setDisplayAddPrivilegeInput(true)

                            scrollToAndClickElement({
                              selector: `.${privilegeSearchClassName} .${MUI_INPUT_BASE_ROOT_CLASSNAME}`,
                            })
                          }}
                        >
                          {translate('text_1753864223060n9hxs03sa15')}
                        </Button>
                      </Tooltip>
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
              formikProps.dirty ? warningDirtyAttributesDialogRef.current?.openDialog() : onLeave()
            }
          >
            {translate('text_6411e6b530cb47007488b027')}
          </Button>
          <Button
            variant="primary"
            disabled={!formikProps.isValid || !formikProps.dirty || isLoading}
            onClick={formikProps.submitForm}
          >
            {translate(
              isEdition ? 'text_17432414198706rdwf76ek3u' : 'text_17561254890574dcio8alli4',
            )}
          </Button>
        </CenteredPage.StickyFooter>
      </CenteredPage.Wrapper>

      <WarningDialog
        ref={warningDirtyAttributesDialogRef}
        title={translate('text_6244277fe0975300fe3fb940')}
        description={translate('text_17561254890579cfr8pj6afl')}
        continueText={translate('text_6244277fe0975300fe3fb94c')}
        onContinue={onLeave}
      />
    </>
  )
}

export default SubscriptionEntitlementForm
