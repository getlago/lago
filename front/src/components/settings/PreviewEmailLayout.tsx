import { FC, PropsWithChildren, useRef } from 'react'

import { Avatar } from '~/components/designSystem/Avatar'
import { Button } from '~/components/designSystem/Button'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { LocaleEnum } from '~/core/translations'
import { PremiumIntegrationTypeEnum } from '~/generated/graphql'
import { useContextualLocale } from '~/hooks/core/useContextualLocale'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import Logo from '~/public/images/logo/lago-logo-grey.svg'

import {
  UpdateBillingEntityLogoDialog,
  UpdateBillingEntityLogoDialogRef,
} from './emails/UpdateBillingEntityLogoDialog'

interface PreviewEmailLayoutProps extends PropsWithChildren {
  language: LocaleEnum
  emailObject?: string
  emailFrom?: string
  emailTo?: string
  isLoading?: boolean
  logoUrl: string | null | undefined
  name?: string | null
}

export const PreviewEmailLayout: FC<PreviewEmailLayoutProps> = ({
  language,
  emailObject,
  emailFrom,
  emailTo,
  isLoading,
  children,
  logoUrl,
  name,
}) => {
  const updateLogoDialogRef = useRef<UpdateBillingEntityLogoDialogRef>(null)

  const { translate } = useInternationalization()
  const { translateWithContextualLocal } = useContextualLocale(language)

  const { hasOrganizationPremiumAddon } = useOrganizationInfos()

  const showPoweredBy = !hasOrganizationPremiumAddon(
    PremiumIntegrationTypeEnum.RemoveBrandingWatermark,
  )

  return (
    <>
      <div>
        {!!emailObject && (
          <>
            {isLoading ? (
              <Skeleton color="dark" variant="text" className="mb-5 w-90" />
            ) : (
              <Typography className="mb-4" variant="bodyHl" color="grey700">
                {emailObject}
              </Typography>
            )}

            <div className="mb-12 flex w-full items-center">
              {isLoading ? (
                <>
                  <Skeleton color="dark" variant="circular" size="big" className="mr-4" />
                  <div>
                    <Skeleton color="dark" variant="text" className="mb-2 w-60" />
                    <Skeleton color="dark" variant="text" className="w-30" />
                  </div>
                </>
              ) : (
                <>
                  <div className="mr-4 size-10 rounded-full bg-grey-300" />
                  <div>
                    <div className="h-[1em]">
                      <Typography variant="captionHl" color="grey700" component="span">
                        {name}
                      </Typography>
                      <Typography variant="note" component="span" className="ml-1">
                        {emailFrom || translate('text_64188b3d9735d5007d712260')}
                      </Typography>
                    </div>
                    <Typography variant="note" component="span">
                      {emailTo || translateWithContextualLocal('text_64188b3d9735d5007d712262')}
                    </Typography>
                  </div>
                </>
              )}
            </div>
          </>
        )}

        <div>
          <div className="mb-8 flex items-center justify-center not-last-child:mr-3">
            {isLoading ? (
              <>
                <Skeleton color="dark" variant="connectorAvatar" size="medium" className="mr-3" />
                <Skeleton color="dark" variant="text" className="w-30" />
              </>
            ) : (
              <>
                {!!logoUrl ? (
                  <Button
                    className="rounded-xl p-0"
                    size="small"
                    variant="quaternary"
                    onClick={() => {
                      updateLogoDialogRef?.current?.openDialog()
                    }}
                  >
                    <Avatar size="medium" variant="connector">
                      <img src={logoUrl} alt="company-logo" />
                    </Avatar>
                  </Button>
                ) : (
                  <Tooltip title={translate('text_6411e0aa915fd500a4d92cfb')} placement="top">
                    <Button
                      icon="plus"
                      size="small"
                      variant="secondary"
                      onClick={() => {
                        updateLogoDialogRef?.current?.openDialog()
                      }}
                    />
                  </Tooltip>
                )}
                <Typography variant="subhead1">{name}</Typography>
              </>
            )}
          </div>

          <section className="mb-8 rounded-xl border border-grey-300 bg-white p-8">
            {children}
          </section>

          {showPoweredBy && (
            <div className="mb-20 flex items-center justify-center [&>svg]:mx-1">
              {isLoading ? (
                <Skeleton color="dark" variant="text" className="w-55" />
              ) : (
                <>
                  <Typography variant="note" color="grey500">
                    {translateWithContextualLocal('text_64188b3d9735d5007d712278')}
                  </Typography>
                  <Logo height="12px" />
                </>
              )}
            </div>
          )}
        </div>
      </div>

      <UpdateBillingEntityLogoDialog ref={updateLogoDialogRef} existingLogoUrl={logoUrl} />
    </>
  )
}
