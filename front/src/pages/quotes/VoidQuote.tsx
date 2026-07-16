import { gql } from '@apollo/client'
import { useMemo } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { Status } from '~/components/designSystem/Status'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { addToast } from '~/core/apolloClient'
import { QuoteDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { EDIT_QUOTE_ROUTE, QUOTE_DETAILS_ROUTE, useNavigate } from '~/core/router'
import { useVoidQuoteVersionMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'
import { usePermissions } from '~/hooks/usePermissions'
import ErrorImage from '~/public/images/maneki/error.svg'
import { PageHeader } from '~/styles'
import { FormLoadingSkeleton, Main, Side } from '~/styles/mainObjectsForm'

import { buildQuotePreviewProps } from './common/buildQuotePreviewProps'
import { getQuoteStatusMapping } from './common/getQuoteStatusMapping'
import { QuotePreviewCard } from './common/QuotePreviewCard'
import { useSharedColumns } from './common/sharedColumns'
import { useCloneQuote } from './hooks/useCloneQuote'
import { useQuote } from './hooks/useQuote'

export const VOID_QUOTE_CLOSE_BUTTON_TEST_ID = 'void-quote-close-button'
export const VOID_QUOTE_VOID_BUTTON_TEST_ID = 'void-quote-void-button'
export const VOID_QUOTE_CANCEL_BUTTON_TEST_ID = 'void-quote-cancel-button'
export const VOID_QUOTE_VOID_AND_GENERATE_BUTTON_TEST_ID = 'void-quote-void-and-generate-button'
export const VOID_QUOTE_ALERT_TEST_ID = 'void-quote-alert'
export const VOID_QUOTE_PREVIEW_TEST_ID = 'void-quote-preview'

gql`
  mutation voidQuoteVersion($input: VoidQuoteVersionInput!) {
    voidQuoteVersion(input: $input) {
      id
      status
    }
  }
`

const VoidQuote = () => {
  const { translate } = useInternationalization()
  const { goBack } = useLocationHistory()
  const { quoteId } = useParams()
  const navigate = useNavigate()
  const { getCreatedAtColumn } = useSharedColumns()

  const { quote, loading, error } = useQuote(quoteId)
  const { hasPermissions } = usePermissions()
  const { cloneQuoteVersion } = useCloneQuote()

  const quoteNumberWithVersion = quote
    ? `${quote.number} - v${quote.versions[0]?.version ?? ''}`
    : ''

  const previewProps = useMemo(
    () =>
      buildQuotePreviewProps({
        version: quote?.currentVersion,
        customer: quote?.customer,
        images: (quote?.images ?? {}) as Record<string, string>,
      }),
    [quote?.currentVersion, quote?.customer, quote?.images],
  )

  const header = {
    documentNumber: quoteNumberWithVersion,
    rows: [translate('text_17818008544903clzyy4ziu1', { quoteNumberWithVersion })],
  }

  const canVoidAndGenerate = hasPermissions(['quotesVoid', 'quotesClone'])

  const [voidQuoteVersionMutation] = useVoidQuoteVersionMutation({
    refetchQueries: ['getQuotes'],
  })

  const versionId = quote?.versions[0]?.id

  const performVoid = async () => {
    if (!quoteId || !versionId) return null

    const result = await voidQuoteVersionMutation({
      variables: {
        input: {
          id: versionId,
        },
      },
    })

    return result.data?.voidQuoteVersion ?? null
  }

  const onSubmit = async () => {
    const voided = await performVoid()

    if (voided) {
      addToast({
        severity: 'success',
        translateKey: 'text_1776414006125gijz56nk7sv',
      })

      navigate(
        generatePath(QUOTE_DETAILS_ROUTE, {
          quoteId: quoteId as string,
          tab: QuoteDetailsTabsOptionsEnum.overview,
        }),
      )
    }
  }

  const onVoidAndGenerateNewVersion = async () => {
    const voided = await performVoid()

    if (voided && versionId) {
      const clonedQuote = await cloneQuoteVersion(versionId)

      if (clonedQuote) {
        navigate(
          generatePath(EDIT_QUOTE_ROUTE, {
            quoteId: clonedQuote.quote.id,
            versionId: clonedQuote.id,
          }),
        )
      }
    }
  }

  const onClose = () => {
    if (quoteId) {
      goBack(
        generatePath(QUOTE_DETAILS_ROUTE, {
          quoteId,
          tab: QuoteDetailsTabsOptionsEnum.overview,
        }),
      )
    }
  }

  if (error) {
    return (
      <GenericPlaceholder
        className="pt-12"
        title={translate('text_634812d6f16b31ce5cbf4126')}
        subtitle={translate('text_634812d6f16b31ce5cbf4128')}
        buttonTitle={translate('text_634812d6f16b31ce5cbf412a')}
        buttonVariant="primary"
        buttonAction={() => location.reload()}
        image={<ErrorImage width="136" height="104" />}
      />
    )
  }

  return (
    <div>
      <PageHeader.Wrapper>
        <Typography variant="bodyHl" color="textSecondary" noWrap>
          {translate('text_1776414006125vf2t8yuiwka', { quoteNumber: quoteNumberWithVersion })}
        </Typography>
        <Button
          data-test={VOID_QUOTE_CLOSE_BUTTON_TEST_ID}
          variant="quaternary"
          icon="close"
          onClick={() => onClose()}
        />
      </PageHeader.Wrapper>

      <div className="min-height-minus-nav flex">
        <Main
          footerAlign="between"
          footer={
            !loading && (
              <>
                <Button
                  data-test={VOID_QUOTE_VOID_BUTTON_TEST_ID}
                  variant="inline"
                  danger
                  onClick={() => onSubmit()}
                >
                  {translate('text_177641400612565v4yq2wx1u')}
                </Button>

                <div className="flex gap-3">
                  <Button
                    data-test={VOID_QUOTE_CANCEL_BUTTON_TEST_ID}
                    variant="quaternary"
                    onClick={() => onClose()}
                  >
                    {translate('text_6411e6b530cb47007488b027')}
                  </Button>
                  {canVoidAndGenerate && (
                    <Button
                      data-test={VOID_QUOTE_VOID_AND_GENERATE_BUTTON_TEST_ID}
                      variant="primary"
                      onClick={() => onVoidAndGenerateNewVersion()}
                    >
                      {translate('text_17764159264034mafl126pox')}
                    </Button>
                  )}
                </div>
              </>
            )
          }
        >
          {loading ? (
            <FormLoadingSkeleton id="void-quote" />
          ) : (
            <div className="flex flex-col gap-12">
              <Alert data-test={VOID_QUOTE_ALERT_TEST_ID} type="warning">
                <Typography className="text-grey-700">
                  {translate('text_1776414006125a67i2j1xl8s')}
                </Typography>
              </Alert>

              <div className="flex flex-col gap-1">
                <Typography variant="headline" color="grey700">
                  {translate('text_1776414006125vf2t8yuiwka', {
                    quoteNumber: quoteNumberWithVersion,
                  })}
                </Typography>
                <Typography variant="body" color="grey600">
                  {translate('text_177641400612546jssznk1w0')}
                </Typography>
              </div>

              <div className="flex flex-col gap-6">
                <Typography variant="subhead1">
                  {translate('text_1776417249197vhv63ozviur')}
                </Typography>
                <Table
                  name="quote-void-details"
                  data={quote ? [quote] : []}
                  containerSize={0}
                  columns={[
                    {
                      key: 'versions.0.status',
                      title: translate('text_63ac86d797f728a87b2f9fa7'),
                      minWidth: 100,
                      content: ({ versions }) => {
                        const status = versions[0]?.status

                        if (!status) return null

                        return <Status {...getQuoteStatusMapping(status, translate)} />
                      },
                    },
                    {
                      key: 'number',
                      title: translate('text_177581001572954eedouxq5u'),
                      maxSpace: true,
                      content: ({ number, versions }) =>
                        `${number} - v${versions[0]?.version ?? ''}`,
                    },
                    {
                      key: 'customer.displayName',
                      title: translate('text_65201c5a175a4b0238abf29a'),
                      maxSpace: true,
                      content: ({ customer }) => customer.displayName,
                    },
                    {
                      key: 'customer.currency',
                      title: translate('text_632b4acf0c41206cbcb8c324'),
                      minWidth: 100,
                      content: ({ customer }) => customer.currency,
                    },
                    getCreatedAtColumn<NonNullable<typeof quote>>(
                      'text_17758254440392sc27lxm6ua',
                      160,
                    ),
                  ]}
                />
              </div>
            </div>
          )}
        </Main>

        <Side>
          <div className="height-minus-nav overflow-auto">
            <QuotePreviewCard
              dataTest={VOID_QUOTE_PREVIEW_TEST_ID}
              loading={loading}
              header={header}
              hasContent={!!quote?.currentVersion?.content}
              previewProps={previewProps}
            />
          </div>
        </Side>
      </div>
    </div>
  )
}

export default VoidQuote
