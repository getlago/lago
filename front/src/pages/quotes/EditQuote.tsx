import { debounce } from 'lodash'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import type {
  OnDiscountCommand,
  OnPricingCommand,
} from '~/components/designSystem/RichTextEditor/common/RichTextEditorContext'
import { DiscountBlockAttributes } from '~/components/designSystem/RichTextEditor/extensions/DiscountBlock.schema'
import { PricingBlockAttributes } from '~/components/designSystem/RichTextEditor/extensions/PricingBlock.schema'
import RichTextEditor, {
  type RichTextEditorMode,
} from '~/components/designSystem/RichTextEditor/RichTextEditor'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Status, StatusType } from '~/components/designSystem/Status'
import { Typography } from '~/components/designSystem/Typography'
import { RightAsidePage } from '~/components/layouts/RightAsidePage'
import { QuoteDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { QUOTE_DETAILS_ROUTE, useNavigate } from '~/core/router'
import type { BillingItemsPayload } from '~/core/serializers/serializeQuoteBillingItems'
import type { Locale } from '~/core/translations'
import { CurrencyEnum, OrderTypeEnum, type UpdateQuoteVersionInput } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { QUOTE_MENTION_VARIABLES } from '~/pages/quotes/common/mentionVariables'

import EditQuoteAside from './editQuote/EditQuoteAside'
import { useAddQuoteImage } from './hooks/useAddQuoteImage'
import { useDiscountDrawer } from './hooks/useDiscountDrawer'
import { useOneOffPricingDrawer } from './hooks/useOneOffPricingDrawer'
import { useQuote } from './hooks/useQuote'
import { useSubscriptionPricingDrawer } from './hooks/useSubscriptionPricingDrawer'
import { useUpdateQuote } from './hooks/useUpdateQuote'

const AUTO_SAVE_DELAY_MS = 2000

type SaveStatus = 'idle' | 'saving' | 'saved' | 'error'

const EditQuote = () => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { quoteId } = useParams()
  const { quote, loading, refetch: refetchQuote } = useQuote(quoteId)

  const { addQuoteImage } = useAddQuoteImage()
  const [uploadedImages, setUploadedImages] = useState<Record<string, string>>({})

  const images = useMemo(
    () => ({ ...((quote?.images ?? {}) as Record<string, string>), ...uploadedImages }),
    [quote?.images, uploadedImages],
  )

  const onImageUpload = useCallback(
    async (base64: string): Promise<string> => {
      if (!quoteId) throw new Error('Missing quote id')

      const { id, url } = await addQuoteImage({ id: quoteId, image: base64 })

      setUploadedImages((prev) => ({ ...prev, [id]: url }))

      return id
    },
    [quoteId, addQuoteImage],
  )

  const versionId = quote?.currentVersion?.id

  const onClose = () => {
    if (!quoteId) return
    navigate(
      generatePath(QUOTE_DETAILS_ROUTE, {
        quoteId,
        tab: QuoteDetailsTabsOptionsEnum.overview,
      }),
    )
  }

  const [saveStatus, setSaveStatus] = useState<SaveStatus>('idle')
  const [editorMode, setEditorMode] = useState<RichTextEditorMode>('edit')

  const onUpdateFinished = useCallback(() => {
    setSaveStatus('saved')
  }, [])

  const onUpdateError = useCallback(() => {
    setSaveStatus('error')
  }, [])

  const { updateQuoteVersion, isUpdatingQuoteVersion, isUpdatingQuote } = useUpdateQuote({
    onUpdateFinished,
    onUpdateError,
  })

  const isUpdating = isUpdatingQuote || isUpdatingQuoteVersion

  const handleSubscriptionDatesChange = useCallback(
    async (startDate?: string, endDate?: string) => {
      if (!versionId) return

      await updateQuoteVersionRef.current({ id: versionId, startDate, endDate }, false)
    },
    [versionId],
  )

  const isSubscriptionOrder =
    quote?.orderType === OrderTypeEnum.SubscriptionCreation ||
    quote?.orderType === OrderTypeEnum.SubscriptionAmendment

  const subscriptionPricing = useSubscriptionPricingDrawer(quote?.currentVersion?.billingItems, {
    quoteDates: {
      startDate:
        quote?.subscription?.subscriptionAt ?? quote?.currentVersion?.startDate ?? undefined,
      endDate: quote?.currentVersion?.endDate ?? undefined,
    },
    onDatesChange: handleSubscriptionDatesChange,
    customer: quote?.customer,
    subscriptionId: quote?.subscription?.id,
  })
  const oneOffPricing = useOneOffPricingDrawer(quote?.currentVersion?.billingItems)

  const { onPricingCommand, isPricingDisabled, entities, syncEntitiesWithBlocks } =
    isSubscriptionOrder ? subscriptionPricing : oneOffPricing

  const quoteCurrency = quote?.customer?.currency ?? CurrencyEnum.Usd

  // Stable ref so useDiscountDrawer can call savePricingBlock without a
  // forward-declaration error (savePricingBlock is defined below).
  const savePricingBlockRef = useRef<(billingItems?: BillingItemsPayload) => void>(() => undefined)

  const discount = useDiscountDrawer(quote?.currentVersion?.billingItems, {
    currency: quoteCurrency,
    onPersist: (billingItems) => savePricingBlockRef.current(billingItems),
  })

  const mergedEntities = useMemo(
    () => ({ ...entities, ...discount.entities }),
    [entities, discount.entities],
  )

  const customerLocale = (quote?.customer?.billingConfiguration?.documentLocale ?? 'en') as Locale

  const getMarkdownRef = useRef<(() => string) | null>(null)
  const lastSavedContentRef = useRef('')
  const isReadyForChangesRef = useRef(false)
  const failedPayloadRef = useRef<UpdateQuoteVersionInput | null>(null)

  // Arm change detection after the editor has fully initialized.
  // Tiptap fires multiple onChange events during setup — we wait for the
  // call stack to clear before starting to track real user edits.
  useEffect(() => {
    if (!quote) return

    const timer = setTimeout(() => {
      const baseline = getMarkdownRef.current?.() ?? ''

      lastSavedContentRef.current = baseline
      isReadyForChangesRef.current = true
    }, 0)

    return () => clearTimeout(timer)
  }, [quote])

  const updateQuoteVersionRef = useRef(updateQuoteVersion)

  updateQuoteVersionRef.current = updateQuoteVersion

  const debouncedSave = useMemo(
    () =>
      debounce(async () => {
        const markdown = getMarkdownRef.current?.()

        if (markdown === null || markdown === undefined || !versionId) return

        const payload: UpdateQuoteVersionInput = { id: versionId, content: markdown }

        failedPayloadRef.current = payload

        try {
          const result = await updateQuoteVersionRef.current(payload, false)

          if (result.data?.updateQuoteVersion) {
            lastSavedContentRef.current = markdown
            failedPayloadRef.current = null
          }
        } catch {
          setSaveStatus('error')
        }
      }, AUTO_SAVE_DELAY_MS),
    [versionId],
  )

  const mentionItems = useMemo(
    () => QUOTE_MENTION_VARIABLES.map((v) => ({ id: v.id, label: translate(v.labelKey) })),
    [translate],
  )

  const mentionValues = useMemo(
    () => (quote?.currentVersion?.mentionVariables ?? {}) as Record<string, string>,
    [quote?.currentVersion?.mentionVariables],
  )

  // Compare content instead of blindly trusting onChange — Tiptap fires onChange
  // on initialization and mode switches, not just on real user edits.
  const handleChange = () => {
    const currentContent = getMarkdownRef.current?.() ?? ''

    if (!isReadyForChangesRef.current) return

    if (currentContent === lastSavedContentRef.current) return

    setSaveStatus('saving')
    debouncedSave()
  }

  const handleRetry = useCallback(async () => {
    const payload = failedPayloadRef.current

    if (!payload) return

    setSaveStatus('saving')

    try {
      const result = await updateQuoteVersionRef.current(payload, false)

      if (result.data?.updateQuoteVersion) {
        if ('content' in payload && payload.content) {
          lastSavedContentRef.current = payload.content
        }
        failedPayloadRef.current = null
      }
    } catch {
      setSaveStatus('error')
    }
  }, [])

  // Keep the ref in sync with the latest savePricingBlock so the stable wrapper
  // passed to useDiscountDrawer always calls the current version.
  const savePricingBlock = useCallback(
    async (billingItems?: BillingItemsPayload) => {
      if (!versionId) return

      const content = getMarkdownRef.current?.()

      if (content === null || content === undefined) return

      setSaveStatus('saving')

      // Each drawer owns a single billingItems category and passes a partial
      // ({ plans } / { addons } / { coupons }) merged over the current items.
      // Normalize here so `addons` is always present on the wire, whichever
      // drawer saved — keeping the backend payload shape stable.
      const payload: UpdateQuoteVersionInput = {
        id: versionId,
        content,
        billingItems: billingItems && { addons: [], ...billingItems },
      }

      failedPayloadRef.current = payload

      try {
        const result = await updateQuoteVersionRef.current(payload, false)

        if (result.data?.updateQuoteVersion) {
          lastSavedContentRef.current = content
          failedPayloadRef.current = null
          refetchQuote()
        }
      } catch {
        setSaveStatus('error')
      }
    },
    [versionId, refetchQuote],
  )

  savePricingBlockRef.current = savePricingBlock

  const handlePricingCommand = useCallback<OnPricingCommand>(
    ({ onSave, editData }) => {
      onPricingCommand({
        onSave: (attrs, entityData, billingItems) => {
          // 1. Insert/update the TipTap node (existing behavior)
          onSave(attrs, entityData, billingItems)
          // 2. Unified save: content + billingItems together
          savePricingBlock(billingItems)
        },
        editData,
      })
    },
    [onPricingCommand, savePricingBlock],
  )

  const handlePricingBlocksChange = useCallback(
    (blocks: PricingBlockAttributes[]) => {
      const updatedBillingItems = syncEntitiesWithBlocks(blocks)

      if (updatedBillingItems) {
        savePricingBlock(updatedBillingItems)
      }
    },
    [syncEntitiesWithBlocks, savePricingBlock],
  )

  const handleDiscountCommand = useCallback<OnDiscountCommand>(
    ({ onSave, editData }) => {
      discount.onDiscountCommand({ onSave, editData })
    },
    [discount],
  )

  const handleDiscountBlocksChange = useCallback(
    (blocks: DiscountBlockAttributes[]) => {
      const updated = discount.syncDiscountBlocks(blocks)

      if (updated) {
        savePricingBlock(updated)
      }
    },
    [discount, savePricingBlock],
  )

  const handleClose = () => {
    debouncedSave.cancel()
    onClose()
  }

  return (
    <RightAsidePage.Wrapper>
      <RightAsidePage.Header
        title={
          <div className="flex flex-row items-center gap-3">
            {loading && (
              <>
                <Skeleton variant="text" className="w-40" />
                <Skeleton variant="text" className="w-12" />
              </>
            )}
            {!loading && quote && (
              <>
                <Typography variant="bodyHl" color="grey700">
                  {quote.number} - v{quote.currentVersion.version}
                </Typography>
                {saveStatus === 'error' ? (
                  <>
                    <Status
                      type={StatusType.warning}
                      label={translate('text_1779437694622y666yr137gm')}
                      endIcon="warning-unfilled"
                    />
                    <Button variant="quaternary" size="small" icon="sync" onClick={handleRetry} />
                  </>
                ) : (
                  <Status
                    type={StatusType.outline}
                    label={translate(
                      saveStatus === 'saving'
                        ? 'text_1779268404389431dgsiiysk'
                        : 'text_1779268404389wpd2ysgatw4',
                    )}
                    endIcon={saveStatus === 'saving' ? 'sync' : 'validate-unfilled'}
                  />
                )}
              </>
            )}
          </div>
        }
        onClose={handleClose}
        isCloseButtonDisabled={isUpdating}
      >
        <Button
          variant="tertiary"
          onClick={() => setEditorMode((m) => (m === 'edit' ? 'preview' : 'edit'))}
        >
          {translate(
            editorMode === 'edit'
              ? 'text_17792789377356rxkbkmpu81'
              : 'text_1779278937735vlpgsllouzy',
          )}
        </Button>
      </RightAsidePage.Header>
      <RightAsidePage.Content
        aside={
          <EditQuoteAside
            quote={quote}
            isSaving={saveStatus === 'saving'}
            onSaveStart={() => setSaveStatus('saving')}
            onSaveFinished={onUpdateFinished}
            onSaveError={(payload) => {
              failedPayloadRef.current = payload
              setSaveStatus('error')
            }}
          />
        }
      >
        {loading ? (
          <div className="mx-auto my-4 flex max-w-4xl flex-col gap-4 px-10">
            <Skeleton variant="text" className="w-3/4" />
            <Skeleton variant="text" className="w-1/2" />
            <Skeleton variant="text" className="w-5/6" />
          </div>
        ) : (
          <RichTextEditor
            content={quote?.currentVersion?.content ?? ''}
            getMarkdownRef={getMarkdownRef}
            onChange={handleChange}
            mode={editorMode}
            onPricingCommand={handlePricingCommand}
            isPricingDisabled={isPricingDisabled}
            entities={mergedEntities}
            onPricingBlocksChange={handlePricingBlocksChange}
            onDiscountCommand={isSubscriptionOrder ? handleDiscountCommand : undefined}
            onDiscountBlocksChange={handleDiscountBlocksChange}
            customerLocale={customerLocale}
            customerCurrency={quote?.customer?.currency ?? undefined}
            variableItems={mentionItems}
            mentionValues={mentionValues}
            images={images}
            onImageUpload={onImageUpload}
          />
        )}
      </RightAsidePage.Content>
    </RightAsidePage.Wrapper>
  )
}

export default EditQuote
