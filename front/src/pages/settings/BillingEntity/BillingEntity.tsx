import { useEffect } from 'react'
import { useParams } from 'react-router-dom'

import { MainHeader } from '~/components/MainHeader/MainHeader'
import { SETTINGS_ROUTE, useNavigate } from '~/core/router'
import { BillingEntity, useGetBillingEntityQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import BillingEntityMain from '~/pages/settings/BillingEntity/sections/BillingEntityMain'

export const BILLING_ENTITY_HEADER_TEST_ID = 'billing-entity-header'
export const BILLING_ENTITY_MAIN_TEST_ID = 'billing-entity-main'
export const BILLING_ENTITY_LOADING_TEST_ID = 'billing-entity-loading'

const BillingEntityPage = () => {
  const { billingEntityCode } = useParams()
  const navigate = useNavigate()
  const { translate } = useInternationalization()

  const { data: billingEntityData, loading: billingEntityLoading } = useGetBillingEntityQuery({
    variables: {
      code: billingEntityCode || '',
    },
    skip: !billingEntityCode,
  })

  const billingEntity = billingEntityData?.billingEntity

  useEffect(() => {
    if (!billingEntityLoading && !billingEntity) {
      navigate(SETTINGS_ROUTE, { replace: true })
    }
  }, [billingEntity, billingEntityLoading, navigate])

  return (
    <>
      <div data-test={BILLING_ENTITY_HEADER_TEST_ID}>
        <MainHeader.Configure
          entity={{
            viewName: billingEntity?.name || '',
            viewNameLoading: billingEntityLoading,
            metadata: translate('text_1742230191029w4pfyxjda2f'),
            metadataLoading: billingEntityLoading,
          }}
        />
      </div>

      {!billingEntityLoading && billingEntity && (
        <div data-test={BILLING_ENTITY_MAIN_TEST_ID}>
          <BillingEntityMain billingEntity={billingEntity as BillingEntity} />
        </div>
      )}
    </>
  )
}

export default BillingEntityPage
