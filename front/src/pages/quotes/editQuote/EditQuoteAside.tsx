import { revalidateLogic, useStore } from '@tanstack/react-form'
import { debounce } from 'lodash'
import { useEffect, useMemo, useRef } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import {
  type CurrencyEnum,
  OrderTypeEnum,
  type QuoteDetailItemFragment,
  type UpdateQuoteVersionInput,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'
import { usePermissions } from '~/hooks/usePermissions'
import {
  buildQuotePreviewProps,
  type QuotePdfHeaderData,
} from '~/pages/quotes/common/buildQuotePreviewProps'
import { useDownloadQuotePdf } from '~/pages/quotes/common/QuotePdfProvider'
import { useApproveQuote } from '~/pages/quotes/hooks/useApproveQuote'
import { useUpdateQuote } from '~/pages/quotes/hooks/useUpdateQuote'

import { type EditQuoteAsideFormValues, editQuoteAsideSchema } from './validationSchema'

import { getQuoteOrderTypeTranslationKey } from '../common/getQuoteOrderTypeTranslationKey'

const AUTO_SAVE_DELAY_MS = 2000

export const EDIT_QUOTE_ASIDE_QUOTE_TYPE_COMBOBOX_TEST_ID = 'edit-quote-aside-quote-type'
export const EDIT_QUOTE_ASIDE_CUSTOMER_INPUT_TEST_ID = 'edit-quote-aside-customer'
export const EDIT_QUOTE_ASIDE_BILLING_ENTITY_INPUT_TEST_ID = 'edit-quote-aside-billing-entity'
export const EDIT_QUOTE_ASIDE_SUBSCRIPTION_INPUT_TEST_ID = 'edit-quote-aside-subscription'
export const EDIT_QUOTE_ASIDE_CURRENCY_INPUT_TEST_ID = 'edit-quote-aside-currency'
export const EDIT_QUOTE_ASIDE_START_DATE_TEST_ID = 'edit-quote-aside-start-date'
export const EDIT_QUOTE_ASIDE_END_DATE_TEST_ID = 'edit-quote-aside-end-date'
export const EDIT_QUOTE_ASIDE_PAYMENT_TERM_TEST_ID = 'edit-quote-aside-payment-term'
export const EDIT_QUOTE_ASIDE_DOWNLOAD_PDF_TEST_ID = 'edit-quote-aside-download-pdf'
export const EDIT_QUOTE_ASIDE_APPROVE_TEST_ID = 'edit-quote-aside-approve'

interface EditQuoteAsideProps {
  quote: QuoteDetailItemFragment | null | undefined
  isSaving?: boolean
  onSaveStart?: () => void
  onSaveFinished?: () => void
  onSaveError?: (payload: UpdateQuoteVersionInput) => void
}

const EditQuoteAside = ({
  quote,
  isSaving,
  onSaveStart,
  onSaveFinished,
  onSaveError,
}: EditQuoteAsideProps) => {
  if (!quote) return null

  return (
    <EditQuoteAsideForm
      quote={quote}
      isSaving={isSaving}
      onSaveStart={onSaveStart}
      onSaveFinished={onSaveFinished}
      onSaveError={onSaveError}
    />
  )
}

const formatNetPaymentTerm = (
  netPaymentTerm: number | null | undefined,
  translate: ReturnType<typeof useInternationalization>['translate'],
): string => {
  if (typeof netPaymentTerm !== 'number') return '-'
  if (netPaymentTerm === 0) return translate('text_64c7a89b6c67eb6c98898125')

  return translate('text_64c7a89b6c67eb6c9889815f', { days: netPaymentTerm }, netPaymentTerm)
}

const EditQuoteAsideForm = ({
  quote,
  isSaving,
  onSaveStart,
  onSaveFinished,
  onSaveError,
}: {
  quote: QuoteDetailItemFragment
  isSaving?: boolean
  onSaveStart?: () => void
  onSaveFinished?: () => void
  onSaveError?: (payload: UpdateQuoteVersionInput) => void
}) => {
  const { translate } = useInternationalization()
  const { updateQuoteVersion } = useUpdateQuote({ onUpdateFinished: onSaveFinished })
  const { hasPermissions } = usePermissions()
  const { download } = useDownloadQuotePdf()
  const { goToApproveQuote } = useApproveQuote()

  const canApprove = hasPermissions(['quotesApprove'])
  const pdfHeader: QuotePdfHeaderData = {
    documentNumber: quote.number,
    rows: [
      translate('text_17818008544903clzyy4ziu1', {
        quoteNumberWithVersion: `${quote.number} - v${quote.currentVersion.version}`,
      }),
    ],
  }

  const hasSubscription = !!quote.subscription
  const isOneOff = quote.orderType === OrderTypeEnum.OneOff
  const versionId = quote.currentVersion.id

  const getDefaultValues = (): EditQuoteAsideFormValues => {
    return {
      orderTypeLabel: translate(getQuoteOrderTypeTranslationKey(quote.orderType)),
      customerName: quote.customer.displayName,
      billingEntityId: quote.customer.billingEntity?.id ?? '',
      currency:
        quote.customer.currency ??
        (quote.currentVersion.currency as CurrencyEnum | undefined) ??
        undefined,
      subscriptionLabel: quote.subscription
        ? `${quote.subscription.plan?.name ?? ''} - ${quote.subscription.externalId}`
        : undefined,
      startDate: quote.subscription?.subscriptionAt ?? quote.currentVersion.startDate ?? undefined,
      endDate: quote.currentVersion.endDate ?? undefined,
      netPaymentTermLabel: formatNetPaymentTerm(
        quote.customer.netPaymentTerm ?? quote.customer.billingEntity?.netPaymentTerm,
        translate,
      ),
    }
  }

  const form = useAppForm({
    defaultValues: getDefaultValues(),
    validationLogic: revalidateLogic({ mode: 'change' }),
    validators: {
      onDynamic: editQuoteAsideSchema,
    },
  })

  // Auto-save dates on change
  const initialDatesRef = useRef({
    startDate: getDefaultValues().startDate,
    endDate: getDefaultValues().endDate,
  })
  // Allow the use of updateQuoteVersion in a memo without using eslint-disable-next-line
  const updateQuoteVersionRef = useRef(updateQuoteVersion)
  const onSaveStartRef = useRef(onSaveStart)
  const onSaveErrorRef = useRef(onSaveError)

  updateQuoteVersionRef.current = updateQuoteVersion
  onSaveStartRef.current = onSaveStart
  onSaveErrorRef.current = onSaveError

  const debouncedSaveDates = useMemo(
    () =>
      debounce(async (startDate?: string, endDate?: string) => {
        if (!versionId) return

        const payload: UpdateQuoteVersionInput = {
          id: versionId,
          startDate,
          endDate,
        }

        try {
          const result = await updateQuoteVersionRef.current(payload, false)

          if (result.data?.updateQuoteVersion) {
            initialDatesRef.current = { startDate, endDate }
          } else {
            onSaveErrorRef.current?.(payload)
          }
        } catch {
          onSaveErrorRef.current?.(payload)
        }
      }, AUTO_SAVE_DELAY_MS),
    [versionId],
  )

  const startDate = useStore(form.store, (state) => state.values.startDate)
  const endDate = useStore(form.store, (state) => state.values.endDate)
  const canSubmit = useStore(form.store, (state) => state.canSubmit)

  useEffect(() => {
    if (!canSubmit) return

    const initial = initialDatesRef.current

    if (startDate === initial.startDate && endDate === initial.endDate) return

    onSaveStartRef.current?.()
    debouncedSaveDates(startDate, endDate)
  }, [startDate, endDate, canSubmit, debouncedSaveDates])

  const gridClassName = 'grid grid-cols-[7.5rem_1fr] items-center gap-0 gap-y-2'

  const handleDownloadPdf = () => {
    download(
      buildQuotePreviewProps({
        version: quote.currentVersion,
        customer: quote.customer,
        images: (quote.images ?? {}) as Record<string, string>,
        header: pdfHeader,
      }),
    ).catch(() => undefined)
  }

  return (
    <div className="flex min-h-full flex-col">
      <div className="flex flex-col gap-3 px-3 py-4">
        <Typography variant="bodyHl" color="grey700">
          {translate('text_1777540287773ez178bggf4h')}
        </Typography>
        <div className={gridClassName}>
          <Typography
            variant="caption"
            color="grey600"
            data-test={EDIT_QUOTE_ASIDE_QUOTE_TYPE_COMBOBOX_TEST_ID}
          >
            {translate('text_1776238919927x1y2z3a4b5c')}
          </Typography>
          <form.AppField name="orderTypeLabel">
            {(field) => <field.TextInputField disabled />}
          </form.AppField>
          {quote.customer.billingEntity && (
            <>
              <Typography
                variant="caption"
                color="grey600"
                data-test={EDIT_QUOTE_ASIDE_BILLING_ENTITY_INPUT_TEST_ID}
              >
                {translate('text_17436114971570doqrwuwhf0')}
              </Typography>
              <form.AppField name="billingEntityId">
                {(field) => (
                  <field.ComboBoxField
                    disabled
                    disableClearable
                    data={[
                      {
                        value: quote.customer.billingEntity.id,
                        label:
                          quote.customer.billingEntity.name || quote.customer.billingEntity.code,
                      },
                    ]}
                  />
                )}
              </form.AppField>
            </>
          )}
        </div>
      </div>
      <hr className="border-grey-300" />
      <div className="flex flex-col gap-3 px-3 py-4">
        <Typography variant="bodyHl" color="grey700">
          {translate('text_1777552621583netdlhbg5i7')}
        </Typography>
        <div className={gridClassName}>
          <Typography
            variant="caption"
            color="grey600"
            data-test={EDIT_QUOTE_ASIDE_CUSTOMER_INPUT_TEST_ID}
          >
            {translate('text_1776238919927l1m2n3o4p5q')}
          </Typography>
          <form.AppField name="customerName">
            {(field) => <field.TextInputField disabled />}
          </form.AppField>

          <Typography
            variant="caption"
            color="grey600"
            data-test={EDIT_QUOTE_ASIDE_CURRENCY_INPUT_TEST_ID}
          >
            {translate('text_632b4acf0c41206cbcb8c324')}
          </Typography>
          <form.AppField name="currency">
            {(field) => (
              <field.ComboBoxField
                disabled
                disableClearable
                data={[
                  ...(quote.customer.currency ? [{ value: quote.customer.currency }] : []),
                  ...(quote.currentVersion.currency && !quote.customer.currency
                    ? [{ value: quote.currentVersion.currency }]
                    : []),
                ]}
              />
            )}
          </form.AppField>

          {quote.subscription && (
            <>
              <Typography
                variant="caption"
                color="grey600"
                data-test={EDIT_QUOTE_ASIDE_SUBSCRIPTION_INPUT_TEST_ID}
              >
                {translate('text_1776238919927d6e7f8g9h0i')}
              </Typography>
              <form.AppField name="subscriptionLabel">
                {(field) => <field.TextInputField disabled />}
              </form.AppField>
            </>
          )}

          {!isOneOff && (
            <>
              <Typography
                variant="caption"
                color="grey600"
                data-test={EDIT_QUOTE_ASIDE_START_DATE_TEST_ID}
              >
                {translate('text_65201c5a175a4b0238abf29e')}
              </Typography>
              <form.AppField name="startDate">
                {(field) => <field.DatePickerField disabled={hasSubscription} placement="auto" />}
              </form.AppField>

              <Typography
                variant="caption"
                color="grey600"
                data-test={EDIT_QUOTE_ASIDE_END_DATE_TEST_ID}
              >
                {translate('text_65201c5a175a4b0238abf2a0')}
              </Typography>
              <form.AppField name="endDate">
                {(field) => <field.DatePickerField placement="auto" />}
              </form.AppField>
            </>
          )}

          <Typography
            variant="caption"
            color="grey600"
            data-test={EDIT_QUOTE_ASIDE_PAYMENT_TERM_TEST_ID}
          >
            {translate('text_1778660219891rv2r5gjmklq')}
          </Typography>
          <form.AppField name="netPaymentTermLabel">
            {(field) => <field.TextInputField disabled />}
          </form.AppField>
        </div>
      </div>
      <div className="sticky bottom-0 mt-auto flex justify-end gap-3 border-t border-grey-200 bg-white p-4">
        <Button
          variant="secondary"
          data-test={EDIT_QUOTE_ASIDE_DOWNLOAD_PDF_TEST_ID}
          loading={isSaving}
          disabled={!!isSaving}
          onClick={handleDownloadPdf}
        >
          {translate('text_17797156485850t8yms6hf7z')}
        </Button>
        {canApprove && (
          <Button
            variant="primary"
            data-test={EDIT_QUOTE_ASIDE_APPROVE_TEST_ID}
            loading={isSaving}
            disabled={!!isSaving}
            onClick={() => goToApproveQuote(quote.id, quote.currentVersion.id)}
          >
            {translate('text_1776848720529vv5zmyyq94k')}
          </Button>
        )}
      </div>
    </div>
  )
}

export default EditQuoteAside
