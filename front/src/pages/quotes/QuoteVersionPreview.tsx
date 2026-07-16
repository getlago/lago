import { useEffect, useMemo } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { Status } from '~/components/designSystem/Status'
import { Typography } from '~/components/designSystem/Typography'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { QuoteDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { EDIT_QUOTE_ROUTE, QUOTE_DETAILS_ROUTE, useNavigate } from '~/core/router'
import { StatusEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'
import ErrorImage from '~/public/images/maneki/error.svg'
import { PageHeader } from '~/styles'
import { FormLoadingSkeleton, Main, Side } from '~/styles/mainObjectsForm'

import { buildQuotePreviewProps } from './common/buildQuotePreviewProps'
import { getQuoteOrderTypeTranslationKey } from './common/getQuoteOrderTypeTranslationKey'
import { getQuoteStatusMapping } from './common/getQuoteStatusMapping'
import { QuotePreviewCard } from './common/QuotePreviewCard'
import { useQuotePreviewVersion } from './hooks/useQuotePreviewVersion'

export const QUOTE_VERSION_PREVIEW_CLOSE_BUTTON_TEST_ID = 'quote-version-preview-close-button'
export const QUOTE_VERSION_PREVIEW_DESCRIPTION_TEST_ID = 'quote-version-preview-description'
export const QUOTE_VERSION_PREVIEW_CARD_TEST_ID = 'quote-version-preview-card'

const QuoteVersionPreview = () => {
  const { translate } = useInternationalization()
  const { goBack } = useLocationHistory()
  const { quoteId, versionId } = useParams()
  const navigate = useNavigate()

  const { quote, loading, error } = useQuotePreviewVersion(quoteId)

  const targetVersion = quote?.versions.find((version) => version.id === versionId)

  // Preview is the canonical surface for non-draft versions only. If the loaded
  // version is missing, send the user back to the details page; if it's a draft
  // (e.g. the preview URL was opened directly), send them to the edit page.
  useEffect(() => {
    if (loading || !quote || !quoteId) return

    if (!targetVersion) {
      navigate(
        generatePath(QUOTE_DETAILS_ROUTE, {
          quoteId,
          tab: QuoteDetailsTabsOptionsEnum.overview,
        }),
      )

      return
    }

    if (targetVersion.status === StatusEnum.Draft && versionId) {
      navigate(generatePath(EDIT_QUOTE_ROUTE, { quoteId, versionId }))
    }
  }, [loading, quote, quoteId, versionId, targetVersion, navigate])

  const previewProps = useMemo(
    () =>
      buildQuotePreviewProps({
        version: targetVersion,
        customer: quote?.customer,
        images: (quote?.images ?? {}) as Record<string, string>,
      }),
    [targetVersion, quote?.customer, quote?.images],
  )

  const quoteNumberWithVersion = quote ? `${quote.number} - v${targetVersion?.version ?? ''}` : ''

  const header = {
    documentNumber: quoteNumberWithVersion,
    rows: [translate('text_17818008544903clzyy4ziu1', { quoteNumberWithVersion })],
  }

  const closeRedirection = () => {
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
          {translate('text_17827453798351lxoetcgnjt', {
            quoteNumber: quote?.number,
            quoteVersion: `v${targetVersion?.version ?? ''}`,
          })}
        </Typography>
        <Button
          data-test={QUOTE_VERSION_PREVIEW_CLOSE_BUTTON_TEST_ID}
          variant="quaternary"
          icon="close"
          onClick={() => closeRedirection()}
        />
      </PageHeader.Wrapper>

      <div className="min-height-minus-nav flex">
        <Main>
          {loading ? (
            <FormLoadingSkeleton id="quote-version-preview" />
          ) : (
            <div className="flex flex-col gap-12">
              <div className="flex flex-col gap-1">
                <Typography variant="headline">
                  {translate('text_17827453798351lxoetcgnjt', {
                    quoteNumber: quote?.number,
                    quoteVersion: `v${targetVersion?.version ?? ''}`,
                  })}
                </Typography>
                <Typography data-test={QUOTE_VERSION_PREVIEW_DESCRIPTION_TEST_ID} color="grey600">
                  {translate('text_1782744552573k822vj4c3o0')}
                </Typography>
              </div>

              <div className="flex flex-col gap-6">
                <Typography variant="subhead1">
                  {translate('text_1776851047915faiji44ys5o')}
                </Typography>
                <DetailsPage.InfoGrid
                  grid={[
                    {
                      label: translate('text_177581001572954eedouxq5u'),
                      value: quote?.number,
                    },
                    {
                      label: translate('text_65201c5a175a4b0238abf29a'),
                      value: quote?.customer.displayName,
                    },
                    {
                      label: translate('text_6560809c38fb9de88d8a52fb'),
                      value: quote
                        ? translate(getQuoteOrderTypeTranslationKey(quote.orderType))
                        : '',
                    },
                    {
                      label: translate('text_63ac86d797f728a87b2f9fa7'),
                      value: targetVersion ? (
                        <Status {...getQuoteStatusMapping(targetVersion.status, translate)} />
                      ) : (
                        ''
                      ),
                    },
                  ]}
                />
              </div>
            </div>
          )}
        </Main>

        <Side>
          <div className="height-minus-nav overflow-auto">
            <QuotePreviewCard
              dataTest={QUOTE_VERSION_PREVIEW_CARD_TEST_ID}
              loading={loading}
              header={header}
              hasContent={!!targetVersion?.content}
              previewProps={previewProps}
            />
          </div>
        </Side>
      </div>
    </div>
  )
}

export default QuoteVersionPreview
