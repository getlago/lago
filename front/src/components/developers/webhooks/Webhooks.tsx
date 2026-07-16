import { gql } from '@apollo/client'
import { useState } from 'react'
import { generatePath } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Table } from '~/components/designSystem/Table/Table'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { WEBHOOK_ROUTE } from '~/components/developers/devtoolsRoutes'
import { useDeleteWebhook } from '~/components/developers/webhooks/useDeleteWebhook'
import {
  SettingsListItem,
  SettingsListItemHeader,
  SettingsListItemLoadingSkeleton,
} from '~/components/layouts/Settings'
import { addToast } from '~/core/apolloClient'
import { CREATE_WEBHOOK_ROUTE, UPDATE_WEBHOOK_ROUTE } from '~/core/router'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { useGetOrganizationHmacDataQuery, useGetWebhookListQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useDeveloperTool } from '~/hooks/useDeveloperTool'
import { useWebhookEventTypes } from '~/hooks/useWebhookEventTypes'

const WEBHOOK_COUNT_LIMIT = 25

gql`
  query getOrganizationHmacData {
    organization {
      id
      hmacKey
    }
  }

  query getWebhookList {
    webhookEndpoints {
      collection {
        id
        name
        webhookUrl
        eventTypes
      }
    }
  }
`

export const Webhooks = () => {
  const { translate } = useInternationalization()
  const { closePanel, setMainRouterUrl } = useDeveloperTool()
  const [showOrganizationHmac, setShowOrganizationHmac] = useState<boolean>(false)
  const { openDialog: openDeleteDialog } = useDeleteWebhook()
  const { data: organizationData, loading: organizationLoading } = useGetOrganizationHmacDataQuery()
  const { data: webhookData, loading: webhookLoading } = useGetWebhookListQuery()
  const { getEventDisplayInfo } = useWebhookEventTypes()

  return (
    <>
      <div>
        <div className="p-4 shadow-b">
          <Typography variant="headline">{translate('text_6271200984178801ba8bdef2')}</Typography>
        </div>

        <div className="flex flex-col gap-12 p-4">
          {webhookLoading && organizationLoading ? (
            <SettingsListItemLoadingSkeleton count={2} />
          ) : (
            <>
              <SettingsListItem className="pb-0 [box-shadow:none]">
                <SettingsListItemHeader
                  label={translate('text_6271200984178801ba8bdf40')}
                  sublabel={translate('text_1746190277237kaa03zrbbd9')}
                  action={
                    <Button
                      disabled={
                        (webhookData?.webhookEndpoints.collection || []).length >=
                        WEBHOOK_COUNT_LIMIT
                      }
                      variant="inline"
                      onClick={() => {
                        // Navigate to BrowserRouter route from MemoryRouter without page reload
                        setMainRouterUrl(CREATE_WEBHOOK_ROUTE)
                        closePanel()
                      }}
                      startIcon="plus"
                    >
                      {translate('text_1746190277237vdc9v07s2fe')}
                    </Button>
                  }
                />

                {!!webhookData?.webhookEndpoints.collection.length && (
                  <Table
                    tableInDialog
                    name="webhooks-list"
                    isLoading={webhookLoading}
                    containerSize={{ default: 0 }}
                    rowSize={48}
                    data={webhookData?.webhookEndpoints.collection || []}
                    columns={[
                      {
                        key: 'id',
                        title: translate('text_1731675102864qdlsq84v1o8'),
                        maxSpace: true,
                        content: ({ name, webhookUrl }) => (
                          <div className="flex flex-col p-2">
                            <Typography color="grey700" variant="body" noWrap>
                              {name || webhookUrl}
                            </Typography>
                            {!!name && (
                              <Typography color="grey500" variant="caption" noWrap>
                                {webhookUrl}
                              </Typography>
                            )}
                          </div>
                        ),
                      },
                      {
                        key: 'eventTypes',
                        title: translate('text_1739181747394snlx2h42642'),
                        minWidth: 120,
                        content: ({ eventTypes }) => {
                          const { eventCount } = getEventDisplayInfo(eventTypes)

                          return (
                            <Typography color="grey600" variant="body">
                              {translate(
                                'text_1739181747394eventscount',
                                { count: eventCount },
                                eventCount,
                              )}
                            </Typography>
                          )
                        },
                      },
                    ]}
                    onRowActionLink={({ id }) => generatePath(WEBHOOK_ROUTE, { webhookId: id })}
                    actionColumnTooltip={() => translate('text_6256de3bba111e00b3bfa51b')}
                    actionColumn={(webhook) => {
                      return [
                        {
                          startIcon: 'pen',
                          title: translate('text_63aa15caab5b16980b21b0b8'),
                          onAction: () => {
                            const path = generatePath(UPDATE_WEBHOOK_ROUTE, {
                              webhookId: webhook.id,
                            })

                            // Navigate to BrowserRouter route from MemoryRouter without page reload
                            setMainRouterUrl(path)
                            closePanel()
                          },
                        },
                        {
                          startIcon: 'trash',
                          title: translate('text_63aa15caab5b16980b21b0ba'),
                          onAction: () => {
                            openDeleteDialog(webhook.id)
                          },
                        },
                      ]
                    }}
                  />
                )}
              </SettingsListItem>

              <SettingsListItem>
                <SettingsListItemHeader
                  label={translate('text_1731675102863c4rd5s6gdlw')}
                  sublabel={translate('text_1731675102864bisv94uujh1')}
                />

                <Table
                  tableInDialog
                  name="organization-hmac-key"
                  isLoading={organizationLoading}
                  containerSize={{ default: 0 }}
                  rowSize={48}
                  data={!!organizationData?.organization ? [organizationData?.organization] : []}
                  columns={[
                    {
                      key: 'hmacKey',
                      title: translate('text_1731079786592ksaixhj9ir9'),
                      minWidth: 147,
                      maxSpace: true,
                      content: ({ hmacKey }) => (
                        <div className="flex items-center gap-2 py-3">
                          <TypographyWithCopy
                            className="ml-0 line-break-auto [text-wrap:auto]"
                            color="grey700"
                            variant="captionCode"
                            masked={!showOrganizationHmac}
                            maskOptions={{ dotsCount: 8, visibleChars: 3 }}
                          >
                            {hmacKey || ''}
                          </TypographyWithCopy>

                          <Tooltip
                            placement="top-start"
                            title={
                              showOrganizationHmac
                                ? translate('text_1731082143943pr83kgzeh86')
                                : translate('text_1731082129536sv17ey4g0sk')
                            }
                          >
                            <Button
                              variant="quaternary"
                              size="small"
                              icon={showOrganizationHmac ? 'eye-hidden' : 'eye'}
                              onClick={() => setShowOrganizationHmac((prev) => !prev)}
                            />
                          </Tooltip>
                        </div>
                      ),
                    },
                  ]}
                  actionColumnTooltip={() => translate('text_646e2d0cc536351b62ba6f01')}
                  actionColumn={({ hmacKey }) => {
                    return [
                      {
                        startIcon: showOrganizationHmac ? 'eye-hidden' : 'eye',
                        title: showOrganizationHmac
                          ? translate('text_1731085297554jks9n068fpp')
                          : translate('text_1731085297554lu61x8djvcr'),
                        onAction: () => {
                          setShowOrganizationHmac((prev) => !prev)
                        },
                      },
                      showOrganizationHmac
                        ? {
                            startIcon: 'duplicate',
                            title: translate('text_637f813d31381b1ed90ab30a'),
                            onAction: () => {
                              copyToClipboard(hmacKey || '')
                              addToast({
                                severity: 'info',
                                translateKey: 'text_1731675102864b4dna9o03pv',
                              })
                            },
                          }
                        : null,
                    ]
                  }}
                />
              </SettingsListItem>
            </>
          )}
        </div>
      </div>
    </>
  )
}
