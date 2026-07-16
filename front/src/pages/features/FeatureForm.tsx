import { FetchResult, gql } from '@apollo/client'
import { useFormik } from 'formik'
import { useCallback, useEffect, useRef, useState } from 'react'
import { generatePath, useParams } from 'react-router-dom'
import { array, object, string } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { WarningDialog, WarningDialogRef } from '~/components/designSystem/WarningDialog'
import { FeaturePrivilegeAccordion } from '~/components/features/FeaturePrivilegeAccordion'
import { TextInput, TextInputField } from '~/components/form'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { FeatureDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { FEATURE_DETAILS_ROUTE, FEATURES_ROUTE, useNavigate } from '~/core/router'
import { scrollToAndExpandAccordion } from '~/core/utils/domUtils'
import { updateNameAndMaybeCode } from '~/core/utils/updateNameAndMaybeCode'
import {
  CreateFeatureMutation,
  FeatureObject,
  FeaturePrivilegeAccordionFragmentDoc,
  LagoApiError,
  PrivilegeValueTypeEnum,
  UpdateFeatureMutation,
  useCreateFeatureMutation,
  useGetFeatureQuery,
  useUpdateFeatureMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { findFirstPrivilegeIndexWithDuplicateCode } from '~/pages/features/utils'
import { FormLoadingSkeleton } from '~/styles/mainObjectsForm'

export type FeatureFormValues = Omit<FeatureObject, 'id' | 'createdAt' | 'subscriptionsCount'>

const SILENT_ERROR_CODES = [LagoApiError.UnprocessableEntity]

gql`
  fragment FeatureForFeatureForm on FeatureObject {
    id
    name
    code
    description
    privileges {
      ...FeaturePrivilegeAccordion
    }
  }

  query getFeature($id: ID!) {
    feature(id: $id) {
      ...FeatureForFeatureForm
    }
  }

  mutation createFeature($input: CreateFeatureInput!) {
    createFeature(input: $input) {
      id
    }
  }

  mutation updateFeature($input: UpdateFeatureInput!) {
    updateFeature(input: $input) {
      id
    }
  }

  ${FeaturePrivilegeAccordionFragmentDoc}
`

const FeatureForm = () => {
  const { featureId = '' } = useParams()
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const isEdition = !!featureId

  const warningDirtyAttributesDialogRef = useRef<WarningDialogRef>(null)
  const [shouldDisplayDescription, setShouldDisplayDescription] = useState<boolean>(false)

  const { data: featureData, loading: featureLoading } = useGetFeatureQuery({
    variables: { id: featureId },
    skip: !featureId,
  })
  const existingFeature = featureData?.feature

  const formikProps = useFormik<FeatureFormValues>({
    initialValues: {
      name: existingFeature?.name || '',
      code: existingFeature?.code || '',
      description: existingFeature?.description || '',
      privileges: existingFeature?.privileges || [],
    },
    validationSchema: object().shape({
      name: string(),
      code: string().required(''),
      description: string(),
      privileges: array()
        .of(
          object().shape({
            name: string(),
            code: string().required(''),
            valueType: string().required(''),
            config: object()
              .when('valueType', {
                is: PrivilegeValueTypeEnum.Select,
                then: (schema) =>
                  schema.shape({
                    selectOptions: array().of(string()).required(''),
                  }),
                otherwise: (schema) => schema.optional(),
              })
              .optional(),
          }),
        )
        .required(''),
    }),
    enableReinitialize: true,
    validateOnMount: true,
    onSubmit: async ({ code, privileges, ...values }) => {
      let result: FetchResult<UpdateFeatureMutation> | FetchResult<CreateFeatureMutation>
      const sanitizedPrivileges = privileges.map((privilege) => ({
        ...privilege,
        // Make sure the id is not defined on update
        id: undefined,
        // Make sure the config is not defined when valueType is not "select"
        config:
          privilege.valueType !== PrivilegeValueTypeEnum.Select ? undefined : privilege.config,
      }))

      if (isEdition) {
        result = await updateFeature({
          variables: {
            input: {
              ...values,
              id: featureId,
              privileges: sanitizedPrivileges,
            },
          },
        })
      } else {
        result = await createFeature({
          variables: {
            input: {
              code,
              ...values,
              privileges: sanitizedPrivileges,
            },
          },
        })
      }

      const { errors } = result

      // For privilege duplicate code, handle error manually
      if (!!errors && hasDefinedGQLError('ValueIsDuplicated', errors, 'privilege.code')) {
        // Find privileges with the code used twice
        const firstPrivilegeIndexWithDuplicateCode =
          findFirstPrivilegeIndexWithDuplicateCode(privileges)

        if (firstPrivilegeIndexWithDuplicateCode !== -1) {
          formikProps.setFieldError(
            `privileges.${firstPrivilegeIndexWithDuplicateCode}.code`,
            'text_632a2d437e341dcc76817556',
          )

          scrollToAndExpandAccordion(`privilege-accordion-${firstPrivilegeIndexWithDuplicateCode}`)
        }
      }
    },
  })

  const onLeave = useCallback(() => {
    if (!!featureId) {
      navigate(
        generatePath(FEATURE_DETAILS_ROUTE, {
          featureId,
          tab: FeatureDetailsTabsOptionsEnum.overview,
        }),
      )
    } else {
      navigate(FEATURES_ROUTE)
    }
  }, [featureId, navigate])

  const [updateFeature, { error: updateError }] = useUpdateFeatureMutation({
    context: {
      silentErrorCodes: SILENT_ERROR_CODES,
    },
    onCompleted({ updateFeature: updatedFeature }) {
      if (!!updatedFeature?.id) {
        addToast({
          severity: 'success',
          translateKey: 'text_1752692673069jy6jh9qsq5q',
        })

        onLeave()
      }
    },
  })

  const [createFeature, { error: createError }] = useCreateFeatureMutation({
    context: {
      silentErrorCodes: SILENT_ERROR_CODES,
    },
    onCompleted({ createFeature: createdFeature }) {
      if (!!createdFeature?.id) {
        addToast({
          severity: 'success',
          translateKey: 'text_1752692673069avy1qgb1ut9',
        })

        onLeave()
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
  }, [createError, updateError])

  useEffect(() => {
    setShouldDisplayDescription(!!existingFeature?.description)
  }, [existingFeature?.description])

  return (
    <>
      <CenteredPage.Wrapper>
        <CenteredPage.Header>
          <Typography variant="bodyHl" color="textSecondary" noWrap>
            {translate(
              isEdition ? 'text_1752692673070znttbx4w0r1' : 'text_17526926730703ysbxa2g5fj',
            )}
          </Typography>

          <Button
            variant="quaternary"
            icon="close"
            onClick={() =>
              formikProps.dirty ? warningDirtyAttributesDialogRef.current?.openDialog() : onLeave()
            }
          />
        </CenteredPage.Header>

        <CenteredPage.Container>
          {featureLoading && <FormLoadingSkeleton id="feature-form" />}
          {!featureLoading && (
            <>
              <div className="not-last-child:mb-1">
                <Typography variant="headline" color="grey700">
                  {translate(
                    isEdition ? 'text_1752692673070lensu4uzy0l' : 'text_17526926730703ysbxa2g5fj',
                  )}
                </Typography>
                <Typography variant="body" color="grey600">
                  {translate('text_17526926730709neo6v3ki3n')}
                </Typography>
              </div>

              <div className="flex flex-col gap-12">
                <section className="pb-12 shadow-b not-last-child:mb-6">
                  <div className="not-last-child:mb-2">
                    <Typography variant="subhead1">
                      {translate('text_1752692673070lgfy2k2bri4')}
                    </Typography>
                    <Typography variant="caption">
                      {translate('text_1752692673070s4ndn9doemg')}
                    </Typography>
                  </div>
                  <div className="flex gap-6 *:flex-1">
                    <TextInput
                      // eslint-disable-next-line jsx-a11y/no-autofocus
                      autoFocus
                      name="name"
                      label={translate('text_1732286530467zstzwbegfiq')}
                      placeholder={translate('text_62876e85e32e0300e1803121')}
                      value={formikProps.values.name || ''}
                      onChange={(name) => {
                        updateNameAndMaybeCode({ name, formikProps })
                      }}
                    />
                    <TextInputField
                      name="code"
                      beforeChangeFormatter={['code']}
                      disabled={isEdition}
                      label={translate('text_62876e85e32e0300e1803127')}
                      placeholder={translate('text_623b42ff8ee4e000ba87d0c4')}
                      formikProps={formikProps}
                      error={formikProps.errors.code}
                    />
                  </div>

                  {shouldDisplayDescription ? (
                    <div className="flex items-center">
                      <TextInputField
                        multiline
                        className="mr-3 flex-1"
                        name="description"
                        label={translate('text_6388b923e514213fed58331c')}
                        placeholder={translate('text_1752693359315hw1mrrfr1hm')}
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
                      fitContent
                      align="left"
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
                      {translate('text_1752693359315oilajtir2uj')}
                    </Typography>
                    <Typography variant="caption">
                      {translate('text_1752693359315aaw5g0bbc1h')}
                    </Typography>
                  </div>
                  <div className="flex flex-col gap-6 *:flex-1">
                    {formikProps.values.privileges.map((privilege, privilegeIndex) => (
                      <FeaturePrivilegeAccordion
                        key={`privilege-accordion-${privilegeIndex}`}
                        id={`privilege-accordion-${privilegeIndex}`}
                        isEdition={isEdition}
                        privilege={privilege}
                        privilegeIndex={privilegeIndex}
                        formikProps={formikProps}
                      />
                    ))}

                    <Button
                      fitContent
                      align="left"
                      variant="inline"
                      startIcon="plus"
                      onClick={() => {
                        formikProps.setFieldValue('privileges', [
                          ...formikProps.values.privileges,
                          {
                            code: '',
                            name: '',
                            valueType: PrivilegeValueTypeEnum.Boolean,
                          },
                        ])
                      }}
                    >
                      {translate('text_1752695518075ut8zscauuq3')}
                    </Button>
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
            data-test="submit"
            variant="primary"
            disabled={!formikProps.isValid || !formikProps.dirty || featureLoading}
            onClick={formikProps.submitForm}
          >
            {translate(
              isEdition ? 'text_1752693359315c6eoxf5szye' : 'text_1752693359315fi592i0bpyz',
            )}
          </Button>
        </CenteredPage.StickyFooter>
      </CenteredPage.Wrapper>

      <WarningDialog
        ref={warningDirtyAttributesDialogRef}
        title={translate('text_6244277fe0975300fe3fb940')}
        description={translate('text_1746623860224gh7o1exyjce')}
        continueText={translate('text_6244277fe0975300fe3fb94c')}
        onContinue={onLeave}
      />
    </>
  )
}

export default FeatureForm
