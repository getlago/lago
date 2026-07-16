import { generatePath, useParams } from 'react-router-dom'

import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import {
  SettingsListItemLoadingSkeleton,
  SettingsPaddedContainer,
} from '~/components/layouts/Settings'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { BILLING_ENTITY_ROUTE } from '~/core/router/SettingRoutes'
import { BillingEntity, useGetBillingEntityQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import InformationBlock from '~/pages/settings/BillingEntity/sections/general/InformationBlock'
import TimezoneBlock from '~/pages/settings/BillingEntity/sections/general/TimezoneBlock'
import ErrorImage from '~/public/images/maneki/error.svg'

const BillingEntityGeneral = () => {
  const { translate } = useInternationalization()
  const { billingEntityCode } = useParams()

  const {
    data: billingEntityData,
    loading: billingEntityLoading,
    error: billingEntityError,
  } = useGetBillingEntityQuery({
    variables: {
      code: billingEntityCode as string,
    },
    skip: !billingEntityCode,
  })

  const billingEntity = billingEntityData?.billingEntity

  if (!!billingEntityError && !billingEntityLoading) {
    return (
      <GenericPlaceholder
        title={translate('text_62bb102b66ff57dbfe7905c0')}
        subtitle={translate('text_62bb102b66ff57dbfe7905c2')}
        buttonTitle={translate('text_62bb102b66ff57dbfe7905c4')}
        buttonVariant="primary"
        buttonAction={() => location.reload()}
        image={<ErrorImage width="136" height="104" />}
      />
    )
  }

  return (
    <>
      <MainHeader.Configure
        breadcrumb={[
          {
            label: billingEntity?.name || '',
            path: generatePath(BILLING_ENTITY_ROUTE, {
              billingEntityCode: billingEntityCode as string,
            }),
          },
        ]}
        entity={{
          viewName: translate('text_1742230191029o8hfgeebxl5'),
          viewNameLoading: billingEntityLoading,
          metadata: translate('text_6380d7e60f081e5b777c4b22'),
          metadataLoading: billingEntityLoading,
        }}
      />

      <SettingsPaddedContainer>
        {!!billingEntityLoading && <SettingsListItemLoadingSkeleton count={5} />}

        {!billingEntityLoading && billingEntity && (
          <>
            <TimezoneBlock billingEntity={billingEntity as BillingEntity} />

            <InformationBlock billingEntity={billingEntity as BillingEntity} />
          </>
        )}
      </SettingsPaddedContainer>
    </>
  )
}

export default BillingEntityGeneral
