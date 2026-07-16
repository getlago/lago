import { gql } from '@apollo/client'
import { useEffect, useMemo } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { FORM_ERRORS_ENUM } from '~/core/constants/form'
import {
  BILLING_ENTITY_GENERAL_ROUTE,
  BILLING_ENTITY_ROUTE,
  ERROR_404_ROUTE,
  SETTINGS_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  CreateBillingEntityInput,
  LagoApiError,
  UpdateBillingEntityInput,
  useCreateBillingEntityMutation,
  useGetBillingEntityQuery,
  useUpdateBillingEntityMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment BillingEntityItem on BillingEntity {
    id
    code
    documentNumbering
    documentNumberPrefix
    logoUrl
    name
    legalName
    legalNumber
    taxIdentificationNumber
    email
    phone
    addressLine1
    addressLine2
    zipcode
    city
    state
    country
    emailSettings
    timezone
    isDefault
    defaultCurrency
    euTaxManagement
    selectedInvoiceCustomSections {
      id
      name
    }
    appliedDunningCampaign {
      id
      name
      code
    }
    einvoicing
  }

  query getBillingEntities {
    billingEntities {
      collection {
        ...BillingEntityItem
      }
    }
  }

  query getBillingEntity($code: String!) {
    billingEntity(code: $code) {
      ...BillingEntityItem
    }
  }

  mutation createBillingEntity($input: CreateBillingEntityInput!) {
    createBillingEntity(input: $input) {
      ...BillingEntityItem
    }
  }

  mutation updateBillingEntity($input: UpdateBillingEntityInput!) {
    updateBillingEntity(input: $input) {
      ...BillingEntityItem
    }
  }
`

const useCreateEditBillingEntity = () => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { billingEntityCode } = useParams<string>()

  const { data, loading, error } = useGetBillingEntityQuery({
    variables: {
      code: billingEntityCode as string,
    },
    skip: !billingEntityCode,
  })

  const billingEntity = data?.billingEntity

  const [create, { error: createError }] = useCreateBillingEntityMutation({
    context: {
      silentErrorCodes: [LagoApiError.UnprocessableEntity],
    },
    onCompleted({ createBillingEntity }) {
      if (!!createBillingEntity) {
        addToast({
          message: translate('text_17430772961894d4a11lxyp5'),
          severity: 'success',
        })

        navigate(
          generatePath(BILLING_ENTITY_ROUTE, {
            billingEntityCode: createBillingEntity.code,
          }),
        )
      }
    },
    refetchQueries: ['getOrganizationInfos'],
  })

  const [update, { error: updateError }] = useUpdateBillingEntityMutation({
    context: {
      silentErrorCodes: [LagoApiError.UnprocessableEntity],
    },
    onCompleted({ updateBillingEntity }) {
      if (!!updateBillingEntity) {
        addToast({
          message: translate('text_1743077296189q7u5nqaylxf'),
          severity: 'success',
        })

        navigate(
          generatePath(BILLING_ENTITY_GENERAL_ROUTE, {
            billingEntityCode: updateBillingEntity.code,
          }),
        )
      }
    },
  })

  const onSave = async (values: CreateBillingEntityInput | UpdateBillingEntityInput) => {
    if (billingEntity && billingEntityCode) {
      return await update({
        variables: {
          input: {
            ...values,
            id: (billingEntity as UpdateBillingEntityInput).id,
          },
        },
      })
    }

    return await create({
      variables: {
        input: values as CreateBillingEntityInput,
      },
    })
  }

  const onClose = () => {
    if (billingEntityCode) {
      return navigate(
        generatePath(BILLING_ENTITY_GENERAL_ROUTE, {
          billingEntityCode,
        }),
      )
    }

    return navigate(generatePath(SETTINGS_ROUTE))
  }

  useEffect(() => {
    if (hasDefinedGQLError('NotFound', error, 'billingEntity')) {
      navigate(ERROR_404_ROUTE)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [error])

  const errorCode = useMemo(() => {
    if (hasDefinedGQLError('ValueAlreadyExist', createError || updateError)) {
      return FORM_ERRORS_ENUM.existingCode
    }

    return undefined
  }, [createError, updateError])

  return {
    loading,
    isEdition: !!billingEntityCode,
    billingEntity,
    errorCode,
    onClose,
    onSave,
  }
}

export default useCreateEditBillingEntity
