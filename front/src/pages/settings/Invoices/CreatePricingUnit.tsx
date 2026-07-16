import { gql } from '@apollo/client'
import { useFormik } from 'formik'
import { useRef, useState } from 'react'
import { useParams } from 'react-router-dom'
import { object, string } from 'yup'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { WarningDialog, WarningDialogRef } from '~/components/designSystem/WarningDialog'
import { TextInput, TextInputField } from '~/components/form'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { INVOICE_SETTINGS_ROUTE, useNavigate } from '~/core/router'
import { updateNameAndMaybeCode } from '~/core/utils/updateNameAndMaybeCode'
import {
  CreatePricingUnitInput,
  LagoApiError,
  useCreatePricingUnitMutation,
  useGetSinglePricingUnitQuery,
  useUpdatePricingUnitMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { FormLoadingSkeleton } from '~/styles/mainObjectsForm'

gql`
  fragment PricingUnit on PricingUnit {
    id
    name
    code
    description
    shortName
  }

  query getSinglePricingUnit($id: ID!) {
    pricingUnit(id: $id) {
      id
      ...PricingUnit
    }
  }

  mutation createPricingUnit($input: CreatePricingUnitInput!) {
    createPricingUnit(input: $input) {
      id
      ...PricingUnit
    }
  }

  mutation updatePricingUnit($input: UpdatePricingUnitInput!) {
    updatePricingUnit(input: $input) {
      id
      ...PricingUnit
    }
  }
`

const CreatePricingUnit = () => {
  const navigate = useNavigate()
  const { translate } = useInternationalization()
  const { pricingUnitId = '' } = useParams()
  const warningDirtyAttributesDialogRef = useRef<WarningDialogRef>(null)
  const isEdition = !!pricingUnitId

  const { data: pricingUnitData, loading: pricingUnitLoading } = useGetSinglePricingUnitQuery({
    variables: {
      id: pricingUnitId,
    },
    skip: !pricingUnitId,
  })

  const [create] = useCreatePricingUnitMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted({ createPricingUnit }) {
      if (!!createPricingUnit?.id) {
        addToast({
          severity: 'success',
          translateKey: 'text_1750318746536n39old34rpc',
        })
      }
      navigate(INVOICE_SETTINGS_ROUTE)
    },
  })

  const [update] = useUpdatePricingUnitMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted({ updatePricingUnit }) {
      if (!!updatePricingUnit?.id) {
        addToast({
          severity: 'success',
          translateKey: 'text_1750318746535n43q7vkxq1h',
        })
      }
      navigate(INVOICE_SETTINGS_ROUTE)
    },
  })

  const formikProps = useFormik<CreatePricingUnitInput>({
    initialValues: {
      name: pricingUnitData?.pricingUnit?.name || '',
      code: pricingUnitData?.pricingUnit?.code || '',
      description: pricingUnitData?.pricingUnit?.description || '',
      shortName: pricingUnitData?.pricingUnit?.shortName || '',
    },
    validationSchema: object().shape({
      name: string().required(''),
      code: string().required(''),
      description: string(),
      shortName: string().required('').max(3, 'text_1750424999815o2wik8216ht'),
    }),
    enableReinitialize: true,
    validateOnMount: true,
    onSubmit: async ({ code, ...values }) => {
      let res

      if (!!pricingUnitId) {
        res = await update({
          variables: {
            input: {
              ...values,
              id: pricingUnitId,
            },
          },
        })
      } else {
        res = await create({
          variables: {
            input: {
              code,
              ...values,
            },
          },
        })
      }

      const { errors } = res

      if (!!errors && hasDefinedGQLError('ValueAlreadyExist', errors)) {
        formikProps.setErrors({
          code: translate('text_632a2d437e341dcc76817556'),
        })
      }
    },
  })

  const [shouldDisplayDescription, setShouldDisplayDescription] = useState(
    !!formikProps.initialValues.description,
  )

  return (
    <>
      <CenteredPage.Wrapper>
        <CenteredPage.Header>
          <Typography variant="bodyHl" color="textSecondary" noWrap>
            {isEdition
              ? translate('text_17502574817266iopiux8fb8')
              : translate('text_1750257481726l1npjihgs20')}
          </Typography>
          <Button
            variant="quaternary"
            icon="close"
            onClick={() =>
              formikProps.dirty
                ? warningDirtyAttributesDialogRef.current?.openDialog()
                : navigate(INVOICE_SETTINGS_ROUTE)
            }
          />
        </CenteredPage.Header>

        <CenteredPage.Container>
          {pricingUnitLoading && <FormLoadingSkeleton id="create-pricing-unit" />}

          {!pricingUnitLoading && (
            <>
              <Alert type="info">{translate('text_1750424999814th7cu8hbg7u')}</Alert>

              <div className="not-last-child:mb-1">
                <Typography variant="headline" color="textSecondary">
                  {translate('text_17502505476284yyq70yy6mx')}
                </Typography>
                <Typography variant="body">{translate('text_1750257831368z0azd7znlhf')}</Typography>
              </div>

              <div className="flex flex-col gap-12">
                <div className="not-last-child:mb-2">
                  <Typography variant="subhead1">
                    {translate('text_17502574817266uy9bvk3i8u')}
                  </Typography>
                  <Typography variant="caption">
                    {translate('text_17502578313682gsr5pls9a3')}
                  </Typography>
                </div>
                <div className="flex flex-col gap-6">
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
                      disabled={isEdition}
                      label={translate('text_62876e85e32e0300e1803127')}
                      placeholder={translate('text_6584550dc4cec7adf8615053')}
                    />
                  </div>

                  <TextInputField
                    name="shortName"
                    formikProps={formikProps}
                    error={formikProps.errors.shortName}
                    label={translate('text_175025054762801ioe61wdye')}
                    placeholder={translate('text_1750250547628xh8057w5j8p')}
                    helperText={translate('text_1750257831368e6n6ys36s6u')}
                  />

                  {shouldDisplayDescription ? (
                    <div className="flex items-center gap-2">
                      <TextInputField
                        className="flex-1"
                        name="description"
                        label={translate('text_623b42ff8ee4e000ba87d0c8')}
                        placeholder={translate('text_1750257831368ae3rtaclhjy')}
                        rows="3"
                        multiline
                        formikProps={formikProps}
                      />

                      <Tooltip
                        className="mt-7"
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
                      align="left"
                      onClick={() => setShouldDisplayDescription(true)}
                      data-test="show-description"
                    >
                      {translate('text_642d5eb2783a2ad10d670324')}
                    </Button>
                  )}
                </div>
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
                : navigate(INVOICE_SETTINGS_ROUTE)
            }
          >
            {translate('text_6411e6b530cb47007488b027')}
          </Button>
          <Button
            variant="primary"
            disabled={!formikProps.isValid || !formikProps.dirty}
            onClick={formikProps.submitForm}
          >
            {isEdition
              ? translate('text_17295436903260tlyb1gp1i7')
              : translate('text_1750319326160woun10ws3h1')}
          </Button>
        </CenteredPage.StickyFooter>
      </CenteredPage.Wrapper>

      <WarningDialog
        ref={warningDirtyAttributesDialogRef}
        title={translate('text_6244277fe0975300fe3fb940')}
        description={translate('text_175025748172630micceie8p')}
        continueText={translate('text_6244277fe0975300fe3fb94c')}
        onContinue={() => navigate(INVOICE_SETTINGS_ROUTE)}
      />
    </>
  )
}

export default CreatePricingUnit
