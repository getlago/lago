import { gql } from '@apollo/client'
import { useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { ShowMoreText } from '~/components/designSystem/ShowMoreText'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import {
  SettingsListItem,
  SettingsListItemHeader,
  SettingsListItemLoadingSkeleton,
  SettingsListWrapper,
  SettingsPaddedContainer,
} from '~/components/layouts/Settings'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import {
  EditBillingEntityDocumentLocaleDialog,
  EditBillingEntityDocumentLocaleDialogRef,
} from '~/components/settings/invoices/EditBillingEntityDocumentLocaleDialog'
import {
  EditBillingEntityGracePeriodDialog,
  EditBillingEntityGracePeriodDialogRef,
} from '~/components/settings/invoices/EditBillingEntityGracePeriodDialog'
import {
  EditBillingEntityInvoiceIssuingDatePolicyDialog,
  EditBillingEntityInvoiceIssuingDatePolicyDialogRef,
} from '~/components/settings/invoices/EditBillingEntityInvoiceIssuingDatePolicyDialog'
import {
  EditBillingEntityInvoiceNumberingDialog,
  EditBillingEntityInvoiceNumberingDialogRef,
} from '~/components/settings/invoices/EditBillingEntityInvoiceNumberingDialog'
import {
  EditBillingEntityInvoiceTemplateDialog,
  EditBillingEntityInvoiceTemplateDialogRef,
} from '~/components/settings/invoices/EditBillingEntityInvoiceTemplateDialog'
import { useEditDefaultCurrencyDialog } from '~/components/settings/invoices/EditDefaultCurrencyDialog'
import {
  EditFinalizeZeroAmountInvoiceDialog,
  EditFinalizeZeroAmountInvoiceDialogRef,
} from '~/components/settings/invoices/EditFinalizeZeroAmountInvoiceDialog'
import {
  EditNetPaymentTermDialog,
  EditNetPaymentTermDialogRef,
} from '~/components/settings/invoices/EditNetPaymentTermDialog'
import {
  INVOICE_ISSUING_DATE_ADJUSTMENT_SETTING_KEYS,
  INVOICE_ISSUING_DATE_ANCHOR_SETTING_KEYS,
} from '~/core/constants/issuingDatePolicy'
import { BILLING_ENTITY_ROUTE } from '~/core/router/SettingRoutes'
import { DocumentLocales } from '~/core/translations/documentLocales'
import { getBillingEntityNumberPreview } from '~/core/utils/billingEntityNumberPreview'
import {
  BillingEntityDocumentNumberingEnum,
  BillingEntitySubscriptionInvoiceIssuingDateAdjustmentEnum,
  BillingEntitySubscriptionInvoiceIssuingDateAnchorEnum,
  DeleteCustomSectionFragmentDoc,
  EditBillingEntityDefaultCurrencyForDialogFragmentDoc,
  EditBillingEntityInvoiceIssuingDatePolicyDialogFragmentDoc,
  EditBillingEntityInvoiceNumberingDialogFragmentDoc,
  EditBillingEntityInvoiceTemplateDialogFragmentDoc,
  EditBillingEntityNetPaymentTermForDialogFragmentDoc,
  useGetBillingEntitySettingsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { usePermissions } from '~/hooks/usePermissions'
import ErrorImage from '~/public/images/maneki/error.svg'

const MAX_FOOTER_LENGTH_DISPLAY_LIMIT = 200

const NUMBERING_TYPE_TRANSLATIONS = {
  [BillingEntityDocumentNumberingEnum.PerCustomer]: 'text_6566f920a1d6c35693d6cdca',
  [BillingEntityDocumentNumberingEnum.PerBillingEntity]: 'text_6566f920a1d6c35693d6cd26',
}

gql`
  query getBillingEntitySettings($code: String!, $appliedToOrganization: Boolean = true) {
    billingEntity(code: $code) {
      id
      code
      name
      netPaymentTerm
      defaultCurrency
      documentNumbering
      documentNumberPrefix
      finalizeZeroAmountInvoice
      billingConfiguration {
        id
        invoiceGracePeriod
        invoiceFooter
        documentLocale
        subscriptionInvoiceIssuingDateAdjustment
        subscriptionInvoiceIssuingDateAnchor
      }
      ...EditBillingEntityInvoiceTemplateDialog
      ...EditBillingEntityNetPaymentTermForDialog
      ...EditBillingEntityDefaultCurrencyForDialog
      ...EditBillingEntityInvoiceNumberingDialog
      ...EditBillingEntityInvoiceIssuingDatePolicyDialog
    }

    taxes(appliedToOrganization: $appliedToOrganization) {
      collection {
        id
        name
        code
        rate
      }
    }

    invoiceCustomSections {
      collection {
        id
        name
        code

        ...DeleteCustomSection
      }
    }
  }

  ${DeleteCustomSectionFragmentDoc}
  ${EditBillingEntityInvoiceTemplateDialogFragmentDoc}
  ${EditBillingEntityNetPaymentTermForDialogFragmentDoc}
  ${EditBillingEntityDefaultCurrencyForDialogFragmentDoc}
  ${EditBillingEntityInvoiceNumberingDialogFragmentDoc}
  ${EditBillingEntityInvoiceIssuingDatePolicyDialogFragmentDoc}
`

const BillingEntityInvoiceSettings = () => {
  const { translate } = useInternationalization()
  const { billingEntityCode } = useParams()
  const { isPremium } = useCurrentUser()
  const { hasPermissions } = usePermissions()

  const editInvoiceTemplateDialogRef = useRef<EditBillingEntityInvoiceTemplateDialogRef>(null)
  const editInvoiceNumberingDialogRef = useRef<EditBillingEntityInvoiceNumberingDialogRef>(null)
  const editBillingEntityInvoiceIssuingDatePolicyDialogRef =
    useRef<EditBillingEntityInvoiceIssuingDatePolicyDialogRef>(null)
  const editGracePeriodDialogRef = useRef<EditBillingEntityGracePeriodDialogRef>(null)
  const editDocumentLanguageDialogRef = useRef<EditBillingEntityDocumentLocaleDialogRef>(null)
  const editNetPaymentTermDialogRef = useRef<EditNetPaymentTermDialogRef>(null)
  const editFinalizeZeroAmountInvoiceDialogRef =
    useRef<EditFinalizeZeroAmountInvoiceDialogRef>(null)
  const premiumWarningDialog = usePremiumWarningDialog()
  const { openEditDefaultCurrencyDialog } = useEditDefaultCurrencyDialog()

  const { data, error, loading } = useGetBillingEntitySettingsQuery({
    variables: {
      code: billingEntityCode as string,
    },
    skip: !billingEntityCode,
  })

  const billingEntity = data?.billingEntity

  const invoiceFooter = billingEntity?.billingConfiguration?.invoiceFooter || ''
  const invoiceGracePeriod = billingEntity?.billingConfiguration?.invoiceGracePeriod || 0
  const documentLocale = billingEntity?.billingConfiguration?.documentLocale || 'en'
  const canEditInvoiceSettings = hasPermissions(['billingEntitiesUpdate'])

  if (!!error && !loading) {
    return (
      <GenericPlaceholder
        title={translate('text_629728388c4d2300e2d380d5')}
        subtitle={translate('text_629728388c4d2300e2d380eb')}
        buttonTitle={translate('text_629728388c4d2300e2d38110')}
        buttonVariant="primary"
        buttonAction={() => location.reload()}
        image={<ErrorImage width="136" height="104" />}
      />
    )
  }

  const items = [
    {
      id: 'invoice-default-currency',
      label: translate('text_6543ca0fdebf76a18e15929c'),
      sublabel: translate('text_17280313005777h5bvs7okol'),
      action: (
        <Button
          variant="inline"
          disabled={!canEditInvoiceSettings}
          onClick={() => openEditDefaultCurrencyDialog({ billingEntity })}
        >
          {translate('text_637f819eff19cd55a56d55e4')}
        </Button>
      ),
      content: billingEntity?.defaultCurrency,
    },
    {
      id: 'invoice-document-locale',
      label: translate('text_63e51ef4985f0ebd75c212fd'),
      sublabel: translate('text_1728031300577ipb2cxnths3'),
      action: (
        <Button
          variant="inline"
          disabled={!canEditInvoiceSettings}
          onClick={() => editDocumentLanguageDialogRef?.current?.openDialog()}
        >
          {translate('text_63e51ef4985f0ebd75c212fc')}
        </Button>
      ),
      content: DocumentLocales[documentLocale as keyof typeof DocumentLocales],
      dialog: (
        <EditBillingEntityDocumentLocaleDialog
          ref={editDocumentLanguageDialogRef}
          documentLocale={documentLocale}
          id={billingEntity?.id as string}
        />
      ),
    },
    {
      id: 'invoice-settings-finalize-zero-amount',
      label: translate('text_1725549671287r9tnu5cuoeu'),
      sublabel: translate('text_1725538340200495slgen6ji'),
      action: (
        <Button
          variant="inline"
          disabled={!canEditInvoiceSettings}
          onClick={() => editFinalizeZeroAmountInvoiceDialogRef?.current?.openDialog()}
        >
          {translate('text_637f819eff19cd55a56d55e4')}
        </Button>
      ),
      content: billingEntity?.finalizeZeroAmountInvoice
        ? translate('text_1725549671287ancbf00edxx')
        : translate('text_1725549671288zkq9sr0y46l'),

      dialog: (
        <EditFinalizeZeroAmountInvoiceDialog
          ref={editFinalizeZeroAmountInvoiceDialogRef}
          entity={billingEntity}
          finalizeZeroAmountInvoice={billingEntity?.finalizeZeroAmountInvoice}
        />
      ),
    },
    {
      id: 'invoice-settings-grace-period',
      label: translate('text_638dc196fb209d551f3d8141'),
      sublabel: translate('text_1728031300577ozl3dbfygr7'),
      action: (
        <Button
          variant="inline"
          endIcon={isPremium ? undefined : 'sparkles'}
          disabled={!canEditInvoiceSettings}
          onClick={() => {
            isPremium
              ? editGracePeriodDialogRef?.current?.openDialog()
              : premiumWarningDialog.open()
          }}
        >
          {translate('text_637f819eff19cd55a56d55e4')}
        </Button>
      ),
      content: translate(
        'text_638dc196fb209d551f3d81a2',
        { gracePeriod: invoiceGracePeriod },
        invoiceGracePeriod,
      ),
      dialog: (
        <EditBillingEntityGracePeriodDialog
          ref={editGracePeriodDialogRef}
          invoiceGracePeriod={invoiceGracePeriod}
          id={billingEntity?.id as string}
        />
      ),
    },
    {
      id: 'invoice-settings-default-footer',
      label: translate('text_637f819eff19cd55a56d55f6'),
      sublabel: translate('text_1728031300577nwh7oc3hawr'),
      action: (
        <Button
          variant="inline"
          disabled={!canEditInvoiceSettings}
          onClick={() => editInvoiceTemplateDialogRef?.current?.openDialog()}
        >
          {translate('text_6380d7e60f081e5b777c4b24')}
        </Button>
      ),
      content: (
        <>
          {!invoiceFooter ? (
            <Typography variant="body" color="grey500">
              {translate('text_637f819eff19cd55a56d55f8')}
            </Typography>
          ) : (
            <ShowMoreText
              variant="body"
              color="grey700"
              text={invoiceFooter}
              limit={MAX_FOOTER_LENGTH_DISPLAY_LIMIT}
            />
          )}
        </>
      ),
      dialog: (
        <EditBillingEntityInvoiceTemplateDialog
          ref={editInvoiceTemplateDialogRef}
          invoiceFooter={invoiceFooter}
          id={billingEntity?.id as string}
        />
      ),
    },
    {
      id: 'invoice-settings-invoice-numbering',
      label: translate('text_6566f920a1d6c35693d6cd16'),
      sublabel: translate('text_17280313005771cdjezfas2e'),
      action: (
        <Button
          variant="inline"
          disabled={!canEditInvoiceSettings}
          onClick={() => editInvoiceNumberingDialogRef?.current?.openDialog()}
        >
          {translate('text_6380d7e60f081e5b777c4b24')}
        </Button>
      ),
      content: (
        <div className="flex items-baseline gap-1">
          <Typography variant="body" color="grey700">
            {getBillingEntityNumberPreview(
              billingEntity?.documentNumbering as BillingEntityDocumentNumberingEnum,
              billingEntity?.documentNumberPrefix || '',
            )}
          </Typography>
          <Typography variant="body" color="grey600">
            {translate(
              NUMBERING_TYPE_TRANSLATIONS[
                billingEntity?.documentNumbering as BillingEntityDocumentNumberingEnum
              ],
            )}
          </Typography>
        </div>
      ),
      dialog: (
        <EditBillingEntityInvoiceNumberingDialog
          ref={editInvoiceNumberingDialogRef}
          documentNumbering={billingEntity?.documentNumbering}
          documentNumberPrefix={billingEntity?.documentNumberPrefix}
          id={billingEntity?.id as string}
        />
      ),
    },
    {
      id: 'invoice-settings-issuing_date-policy',
      label: translate('text_1763407530093r6zuzwr3x7p'),
      sublabel: translate('text_1763407530094ffluzv9nvij'),
      action: (
        <Button
          variant="inline"
          disabled={!canEditInvoiceSettings}
          onClick={() => editBillingEntityInvoiceIssuingDatePolicyDialogRef?.current?.openDialog()}
        >
          {translate('text_6380d7e60f081e5b777c4b24')}
        </Button>
      ),
      content: (
        <div className="flex items-baseline gap-1">
          <Typography variant="body" color="grey700">
            <div>
              {translate(
                INVOICE_ISSUING_DATE_ANCHOR_SETTING_KEYS[
                  billingEntity?.billingConfiguration?.subscriptionInvoiceIssuingDateAnchor ||
                    BillingEntitySubscriptionInvoiceIssuingDateAnchorEnum.NextPeriodStart
                ],
              )}
            </div>
            <div>
              {translate(
                INVOICE_ISSUING_DATE_ADJUSTMENT_SETTING_KEYS[
                  billingEntity?.billingConfiguration?.subscriptionInvoiceIssuingDateAdjustment ||
                    BillingEntitySubscriptionInvoiceIssuingDateAdjustmentEnum.AlignWithFinalizationDate
                ],
              )}
            </div>
          </Typography>
        </div>
      ),
      dialog: (
        <>
          {!!billingEntity && (
            <EditBillingEntityInvoiceIssuingDatePolicyDialog
              ref={editBillingEntityInvoiceIssuingDatePolicyDialogRef}
              billingEntity={billingEntity}
            />
          )}
        </>
      ),
    },
    {
      id: 'invoice-settings-net-payment-term',
      label: translate('text_64c7a89b6c67eb6c98898167'),
      sublabel: translate('text_1728031300577aivplw3hqav'),
      action: (
        <Button
          variant="inline"
          disabled={!canEditInvoiceSettings}
          onClick={() => editNetPaymentTermDialogRef?.current?.openDialog(billingEntity)}
        >
          {translate('text_637f819eff19cd55a56d55e4')}
        </Button>
      ),
      content: translate(
        'text_64c7a89b6c67eb6c9889815f',
        {
          days: billingEntity?.netPaymentTerm,
        },
        billingEntity?.netPaymentTerm,
      ),
      dialog: (
        <EditNetPaymentTermDialog
          ref={editNetPaymentTermDialogRef}
          description={translate('text_64c7a89b6c67eb6c988980eb')}
        />
      ),
    },
  ]

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
          viewName: translate('text_62ab2d0396dd6b0361614d24'),
          viewNameLoading: loading,
          metadata: translate('text_637f819eff19cd55a56d55e2'),
          metadataLoading: loading,
        }}
      />

      <SettingsPaddedContainer>
        <SettingsListWrapper>
          {!!loading && <SettingsListItemLoadingSkeleton count={6} />}

          {!loading &&
            items.map((item) => (
              <SettingsListItem key={item.id}>
                <SettingsListItemHeader
                  label={item.label}
                  sublabel={item.sublabel}
                  action={item.action}
                />

                <Typography variant="body" color="grey700">
                  {item.content}
                </Typography>
              </SettingsListItem>
            ))}
        </SettingsListWrapper>
      </SettingsPaddedContainer>

      {items.map((item) => (
        <div key={`billing-entity-invoice-settings-dialog-${item.id}`}>{item.dialog}</div>
      ))}
    </>
  )
}

export default BillingEntityInvoiceSettings
