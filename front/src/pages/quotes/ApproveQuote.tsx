import { revalidateLogic, useStore } from '@tanstack/react-form'
import { useMemo } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { addToast } from '~/core/apolloClient'
import { QuoteDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { QUOTE_DETAILS_ROUTE, useNavigate } from '~/core/router'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'
import { useAppForm } from '~/hooks/forms/useAppform'
import ErrorImage from '~/public/images/maneki/error.svg'
import { PageHeader } from '~/styles'
import { FormLoadingSkeleton, Main, Side } from '~/styles/mainObjectsForm'

import {
  approveQuoteDefaultValues,
  approveQuoteValidationSchema,
  buildApproveQuoteVersionInput,
} from './approveQuote/validationSchema'
import { buildQuotePreviewProps } from './common/buildQuotePreviewProps'
import { getQuoteOrderTypeTranslationKey } from './common/getQuoteOrderTypeTranslationKey'
import { QuotePreviewCard } from './common/QuotePreviewCard'
import { useApproveQuote } from './hooks/useApproveQuote'
import { useQuote } from './hooks/useQuote'

export const APPROVE_QUOTE_CLOSE_BUTTON_TEST_ID = 'approve-quote-close-button'
export const APPROVE_QUOTE_APPROVE_BUTTON_TEST_ID = 'approve-quote-approve-button'
export const APPROVE_QUOTE_CANCEL_BUTTON_TEST_ID = 'approve-quote-cancel-button'
export const APPROVE_QUOTE_ALERT_TEST_ID = 'approve-quote-alert'
export const APPROVE_QUOTE_PREVIEW_TEST_ID = 'approve-quote-preview'

const ApproveQuote = () => {
  const { translate } = useInternationalization()
  const { goBack } = useLocationHistory()
  const { quoteId, versionId } = useParams()
  const navigate = useNavigate()
  const centralizedDialog = useCentralizedDialog()

  const { quote, loading, error } = useQuote(quoteId)
  const { approveQuote } = useApproveQuote()

  // Single source of truth for preview inputs (shared with the PDF renderer).
  const previewProps = useMemo(
    () =>
      buildQuotePreviewProps({
        version: quote?.currentVersion,
        customer: quote?.customer,
        images: (quote?.images ?? {}) as Record<string, string>,
      }),
    [quote?.currentVersion, quote?.customer, quote?.images],
  )

  const quoteNumberWithVersion = quote
    ? `${quote.number} - v${quote.currentVersion?.version ?? ''}`
    : ''

  const header = {
    documentNumber: quoteNumberWithVersion,
    rows: [translate('text_17818008544903clzyy4ziu1', { quoteNumberWithVersion })],
  }

  const form = useAppForm({
    defaultValues: approveQuoteDefaultValues,
    validationLogic: revalidateLogic(),
    validators: { onDynamic: approveQuoteValidationSchema },
    onSubmit: async ({ value }) => {
      if (!quoteId || !versionId) return

      const result = await approveQuote({
        variables: { input: buildApproveQuoteVersionInput(versionId, value) },
      })

      if (result.data?.approveQuoteVersion) {
        addToast({ severity: 'success', translateKey: 'text_1776848720529o2nn0q3b7iv' })

        navigate(
          generatePath(QUOTE_DETAILS_ROUTE, {
            quoteId,
            tab: QuoteDetailsTabsOptionsEnum.orderForms,
          }),
        )
      }
    },
  })

  const isDirty = useStore(form.store, (state) => state.isDirty)

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

  const onClose = () => {
    if (!isDirty) {
      closeRedirection()

      return
    }

    centralizedDialog.open({
      title: translate('text_665deda4babaf700d603ea13'),
      description: translate('text_665dedd557dc3c00c62eb83d'),
      actionText: translate('text_645388d5bdbd7b00abffa033'),
      colorVariant: 'danger',
      onAction: () => closeRedirection(),
    })
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
          {translate('text_17768509988630g6v99v8x8h', {
            quoteNumber: quote?.number,
            quoteVersion: `v${quote?.currentVersion?.version}`,
          })}
        </Typography>
        <Button
          data-test={APPROVE_QUOTE_CLOSE_BUTTON_TEST_ID}
          variant="quaternary"
          icon="close"
          onClick={() => onClose()}
        />
      </PageHeader.Wrapper>

      <div className="min-height-minus-nav flex">
        <Main
          footer={
            !loading && (
              <>
                <Button
                  data-test={APPROVE_QUOTE_CANCEL_BUTTON_TEST_ID}
                  variant="quaternary"
                  onClick={() => onClose()}
                >
                  {translate('text_6411e6b530cb47007488b027')}
                </Button>
                <Button
                  data-test={APPROVE_QUOTE_APPROVE_BUTTON_TEST_ID}
                  variant="primary"
                  onClick={() => form.handleSubmit()}
                >
                  {translate('text_1776848720529vv5zmyyq94k')}
                </Button>
              </>
            )
          }
        >
          {loading ? (
            <FormLoadingSkeleton id="approve-quote" />
          ) : (
            <div className="flex flex-col gap-12">
              <Alert data-test={APPROVE_QUOTE_ALERT_TEST_ID} type="info">
                <Typography className="text-grey-700">
                  {translate('text_1776848720529x0n0j0tob0w')}
                </Typography>
              </Alert>

              <div className="flex flex-col gap-1">
                <Typography variant="headline">
                  {translate('text_17768509988630g6v99v8x8h', {
                    quoteNumber: quote?.number,
                    quoteVersion: `v${quote?.currentVersion?.version}`,
                  })}
                </Typography>
                <Typography color="grey600">
                  {translate('text_1776850998863xqfl9h0n6rc')}
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
                  ]}
                />
              </div>

              <div className="flex flex-col gap-6">
                <form.AppField name="expiresAt">
                  {(field) => (
                    <field.DatePickerField
                      label={translate('text_1781872376833n9vthkte11e')}
                      placeholder={translate('text_62cd78ea9bff25e3391b2437')}
                      disablePast
                      placement="top-end"
                    />
                  )}
                </form.AppField>
              </div>
            </div>
          )}
        </Main>

        <Side>
          <div className="height-minus-nav overflow-auto">
            <QuotePreviewCard
              dataTest={APPROVE_QUOTE_PREVIEW_TEST_ID}
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

export default ApproveQuote
