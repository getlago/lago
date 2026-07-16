import { Icon, tw } from 'lago-design-system'

import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { PreviewEmailLayout } from '~/components/settings/PreviewEmailLayout'
import { envGlobalVar } from '~/core/apolloClient'
import { LocaleEnum } from '~/core/translations'
import {
  BillingEntityEmailSettingsEnum,
  GetBillingEntityQuery,
  GetCreditNoteForDetailsQuery,
  GetInvoiceDetailsQuery,
  GetPaymentDetailsQuery,
} from '~/generated/graphql'
import { useContextualLocale } from '~/hooks/core/useContextualLocale'
import { useEmailPreviewTranslationsKey } from '~/hooks/useEmailPreviewTranslationsKey'

export enum DisplayEnum {
  desktop = 'desktop',
  mobile = 'mobile',
}

export type BillingEntity =
  | GetBillingEntityQuery['billingEntity']
  | NonNullable<GetInvoiceDetailsQuery['invoice']>['billingEntity']
  | NonNullable<GetCreditNoteForDetailsQuery['creditNote']>['billingEntity']
  | NonNullable<GetPaymentDetailsQuery['payment']>['customer']['billingEntity']

export type DocumentData = {
  // Common — formatted total amount (e.g., "$1,234.56")
  amount?: string
  // Invoice
  invoiceNumber?: string
  issueDate?: string
  // Credit Note
  creditNoteNumber?: string
  // Payment Receipt
  receiptNumber?: string
  paymentDate?: string
  paymentMethod?: string
  amountPaid?: string
  invoices?: Array<{ number: string; amount: string }>
}

type EmailPreviewProps = {
  loading: boolean
  display?: DisplayEnum
  invoiceLanguage?: LocaleEnum
  type?: BillingEntityEmailSettingsEnum
  billingEntity?: BillingEntity
  showEmailHeader?: boolean
  documentData?: DocumentData
}

const { disablePdfGeneration } = envGlobalVar()

const EmailPreview = ({
  loading,
  invoiceLanguage = LocaleEnum.en,
  display = DisplayEnum.desktop,
  type,
  billingEntity,
  showEmailHeader = true,
  documentData,
}: EmailPreviewProps) => {
  const { translateWithContextualLocal } = useContextualLocale(invoiceLanguage)
  const { mapTranslationsKey } = useEmailPreviewTranslationsKey()
  const translationsKey = mapTranslationsKey(type)

  const billingEntityName = billingEntity?.name
  const billingEntityEmail = billingEntity?.email

  return (
    <div className="flex w-full flex-1 justify-center bg-grey-100">
      <div
        className={tw(
          'px-4 pb-0 pt-12',
          display === DisplayEnum.desktop ? 'w-150 max-w-150' : 'w-90 max-w-90',
        )}
      >
        <PreviewEmailLayout
          isLoading={loading}
          language={invoiceLanguage}
          logoUrl={billingEntity?.logoUrl}
          emailObject={
            showEmailHeader
              ? translateWithContextualLocal(translationsKey.subject, {
                  organization: billingEntityName,
                })
              : undefined
          }
        >
          <div className="flex flex-col items-center justify-center">
            {loading ? (
              <>
                <Skeleton color="dark" variant="text" className="mb-5 w-30" />
                <Skeleton color="dark" variant="text" className="mb-5 w-40" />
                <Skeleton color="dark" variant="text" className="mb-7 w-30" />
                <Skeleton color="dark" variant="text" className="mb-7" />
                <div className="flex w-full justify-between">
                  <Skeleton color="dark" variant="text" className="mb-4 w-30" />
                  <Skeleton color="dark" variant="text" className="mb-4 w-40" />
                </div>
                <div className="flex w-full justify-between">
                  <Skeleton color="dark" variant="text" className="mb-4 w-30" />
                  <Skeleton color="dark" variant="text" className="mb-4 w-40" />
                </div>
              </>
            ) : (
              <>
                <Typography variant="caption">
                  {translateWithContextualLocal(translationsKey.invoice_from, {
                    organization: billingEntityName,
                  })}
                </Typography>
                <Typography variant="headline">
                  {documentData?.amount ?? translateWithContextualLocal(translationsKey.amount)}
                </Typography>
                <div className="my-6 h-px w-full bg-grey-300" />
                <div className="flex w-full flex-col gap-1">
                  {type === BillingEntityEmailSettingsEnum.CreditNoteCreated && (
                    <div className="flex w-full items-center justify-between">
                      <Typography variant="caption">
                        {!!translationsKey.credit_note_number &&
                          translateWithContextualLocal(translationsKey.credit_note_number)}
                      </Typography>
                      <Typography variant="caption" color="grey700">
                        {documentData?.creditNoteNumber ??
                          (!!translationsKey.credit_note_number_value &&
                            translateWithContextualLocal(translationsKey.credit_note_number_value))}
                      </Typography>
                    </div>
                  )}
                  {type === BillingEntityEmailSettingsEnum.PaymentReceiptCreated && (
                    <>
                      {(
                        [
                          [
                            translationsKey.receipt_number,
                            translationsKey.receipt_number_value,
                            documentData?.receiptNumber,
                          ],
                          [
                            translationsKey.payment_date,
                            translationsKey.payment_date_value,
                            documentData?.paymentDate,
                          ],
                          [
                            translationsKey.payment_method,
                            translationsKey.payment_method_value,
                            documentData?.paymentMethod,
                          ],
                          [
                            translationsKey.amount_paid,
                            translationsKey.amount_paid_value,
                            documentData?.amountPaid,
                          ],
                        ] as const
                      ).map(([label, fallbackValue, overrideValue]) => (
                        <div className="flex w-full items-center justify-between" key={label}>
                          <Typography variant="caption">
                            {!!label && translateWithContextualLocal(label)}
                          </Typography>
                          <Typography variant="caption" color="grey700">
                            {overrideValue ??
                              (!!fallbackValue && translateWithContextualLocal(fallbackValue))}
                          </Typography>
                        </div>
                      ))}

                      <div className="mt-6 flex w-full items-center justify-between">
                        <Typography variant="caption" color="grey700">
                          {translateWithContextualLocal('text_6419c64eace749372fc72b3c')}
                        </Typography>
                        <Typography variant="caption" color="grey700">
                          {translateWithContextualLocal('text_6419c64eace749372fc72b3e')}
                        </Typography>
                      </div>

                      {(
                        documentData?.invoices ?? [
                          { number: 'INV-001-001', amount: '$730,00' },
                          { number: 'INV-001-002', amount: '$730,00' },
                          { number: 'INV-001-003', amount: '$730,00' },
                          { number: 'INV-001-004', amount: '$730,00' },
                        ]
                      ).map((invoice) => (
                        <div
                          className="flex w-full items-center justify-between"
                          key={invoice.number}
                        >
                          <Typography variant="caption">{invoice.number}</Typography>
                          <Typography variant="caption" color="grey700">
                            {invoice.amount}
                          </Typography>
                        </div>
                      ))}
                    </>
                  )}

                  {translationsKey.invoice_number && translationsKey.invoice_number_value && (
                    <div className="flex w-full items-center justify-between">
                      <Typography variant="caption">
                        {translateWithContextualLocal(translationsKey.invoice_number)}
                      </Typography>
                      <Typography variant="caption" color="grey700">
                        {documentData?.invoiceNumber ??
                          translateWithContextualLocal(translationsKey.invoice_number_value)}
                      </Typography>
                    </div>
                  )}

                  {translationsKey.issue_date && translationsKey.issue_date_value && (
                    <div className="flex w-full items-center justify-between">
                      <Typography variant="caption">
                        {translateWithContextualLocal(translationsKey.issue_date)}
                      </Typography>
                      <Typography variant="caption" color="grey700">
                        {documentData?.issueDate ??
                          translateWithContextualLocal(translationsKey.issue_date_value)}
                      </Typography>
                    </div>
                  )}
                </div>

                {!disablePdfGeneration && (
                  <>
                    <div className="my-6 h-px w-full bg-grey-300" />

                    {type === BillingEntityEmailSettingsEnum.PaymentReceiptCreated ? (
                      <div className="flex flex-row items-center gap-6">
                        <div className="flex items-center gap-2">
                          <Icon name="arrow-bottom" color="primary" />
                          <Typography variant="caption" color="grey700">
                            {translateWithContextualLocal('text_17413343926225ug14ak60xv')}
                          </Typography>
                        </div>

                        <div className="flex items-center gap-2">
                          <Icon name="arrow-bottom" color="primary" />
                          <Typography variant="caption" color="grey700">
                            {translateWithContextualLocal('text_1741334392622fl3ozwejrul')}
                          </Typography>
                        </div>
                      </div>
                    ) : (
                      <div className="flex flex-row items-center gap-2">
                        <Icon name="arrow-bottom" color="primary" />
                        <Typography variant="caption" color="grey700">
                          {translateWithContextualLocal('text_64188b3d9735d5007d712274')}
                        </Typography>
                      </div>
                    )}
                  </>
                )}

                <div className="my-6 h-px w-full bg-grey-300" />
                <Typography className="text-center" variant="caption">
                  <span className="mr-1">
                    {translateWithContextualLocal('text_64188b3d9735d5007d712276')}
                  </span>
                  <span className="text-blue-600">
                    {billingEntityEmail || 'billing@user_email.com'}
                  </span>
                </Typography>
              </>
            )}
          </div>
        </PreviewEmailLayout>
      </div>
    </div>
  )
}

export default EmailPreview
