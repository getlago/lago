import { forwardRef, useEffect, useImperativeHandle, useRef, useState } from 'react'

import { ChargeSummarySection } from '~/components/customers/usage/sections/ChargeSummarySection'
import { FiltersOnlyTable } from '~/components/customers/usage/sections/FiltersOnlyTable'
import { GroupedUsageTable } from '~/components/customers/usage/sections/GroupedUsageTable'
import { GroupedUsageWithFiltersTable } from '~/components/customers/usage/sections/GroupedUsageWithFiltersTable'
import { SubscriptionUsageDetailDrawerUsage } from '~/components/customers/usage/usageDetailsHelpers'
import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Drawer, DrawerRef } from '~/components/designSystem/Drawer'
import { NavigationTab, TabManagedBy } from '~/components/designSystem/NavigationTab'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { intlFormatDateTime } from '~/core/timezone'
import { LocaleEnum } from '~/core/translations'
import { CurrencyEnum, ProjectedChargeUsage, TimezoneEnum } from '~/generated/graphql'
import { TranslateFunc } from '~/hooks/core/useInternationalization'

// Side-effect import: registers the `CustomerUsageForUsageDetails` and
// `CustomerProjectedUsageForUsageDetails` fragments with codegen so the
// generated `FragmentDoc` exports stay in sync.
import './usageDetailsFragments'

// Re-export helpers + types for callers and tests that depend on them through
// this module's surface.
export {
  isBreakdownRow,
  makeBreakdownRows,
  sumBreakdownUnits,
  type PresentationBreakdownRow,
  type SubscriptionUsageDetailDrawerUsage,
} from '~/components/customers/usage/usageDetailsHelpers'

export interface SubscriptionUsageDetailDrawerRef {
  openDrawer: (
    usage: SubscriptionUsageDetailDrawerUsage,
    refreshUsage: () => Promise<SubscriptionUsageDetailDrawerUsage | undefined>,
    defaultTab?: number,
  ) => unknown
  closeDialog: () => unknown
}

interface SubscriptionUsageDetailDrawerProps {
  currency: CurrencyEnum
  fromDatetime: string
  toDatetime: string
  customerTimezone: TimezoneEnum
  translate: TranslateFunc
  locale?: LocaleEnum
}

export const SubscriptionUsageDetailDrawer = forwardRef<
  SubscriptionUsageDetailDrawerRef,
  SubscriptionUsageDetailDrawerProps
>(
  (
    {
      currency,
      fromDatetime,
      toDatetime,
      customerTimezone,
      translate,
      locale,
    }: SubscriptionUsageDetailDrawerProps,
    ref,
  ) => {
    const drawerRef = useRef<DrawerRef>(null)
    const [usage, setUsage] = useState<SubscriptionUsageDetailDrawerUsage>()
    const [refreshFunction, setRefreshFunction] =
      useState<
        (forceProjected?: boolean) => Promise<SubscriptionUsageDetailDrawerUsage | undefined>
      >()
    const [activeTab, setActiveTab] = useState<number>(0)
    const [fetchedProjected, setFetchedProjected] = useState(false)

    const showProjected = activeTab === 1

    useEffect(() => {
      const f = async () => {
        if (showProjected && !fetchedProjected) {
          const res = await refreshFunction?.(true)

          setUsage(res)

          setFetchedProjected(true)
        }
      }

      f()
    }, [fetchedProjected, refreshFunction, showProjected])

    const unitsHeader = showProjected
      ? translate('text_17531019276915hby502cvzy')
      : translate('text_1753095789277t9kbe8y5pmh')
    const amountHeader = showProjected
      ? translate('text_1753101927691j5chrkhmoma')
      : translate('text_1753101927691fbbwyk7p39q')

    const displayName = usage?.charge.invoiceDisplayName || usage?.billableMetric.name
    const hasAnyFilterInGroupUsage = usage?.groupedUsage?.some(
      (u) => (u?.filters || [])?.length > 0,
    )
    const hasAnyUnitsInGroupUsage = usage?.groupedUsage?.some((u) => u?.units > 0)

    // Section 2 ("Usage linked to charge filters and pricing groups") renders
    // a breakdown table when there are charge filters or grouped usage entries
    // to break down. Otherwise it shows the info alert.
    const hasFiltersOrGroups =
      (usage?.filters?.length ?? 0) > 0 || (usage?.groupedUsage?.length ?? 0) > 0
    // Charge-level presentation breakdowns are already rendered in Section 1.
    // When that's the only thing this charge has, suppress Section 2 entirely
    // so the user doesn't see a contradictory "no filters / no PGK" alert next
    // to the breakdowns that ARE displayed above. Account for both the current
    // and projected breakdown fields — either set indicates Section 1 will
    // have breakdowns under it on its respective tab.
    const hasChargeLevelBreakdowns =
      (usage?.presentationBreakdowns?.length ?? 0) > 0 ||
      ((usage as ProjectedChargeUsage | undefined)?.projectedPresentationBreakdowns?.length ?? 0) >
        0
    const showSection2 = hasFiltersOrGroups || !hasChargeLevelBreakdowns

    useImperativeHandle(ref, () => ({
      openDrawer: (data, refreshData, defaultTab) => {
        setUsage(data)
        setRefreshFunction(() => refreshData)
        setActiveTab(defaultTab || 0)
        setFetchedProjected(defaultTab === 1)

        drawerRef.current?.openDrawer()
      },
      closeDialog: () => drawerRef.current?.closeDrawer(),
    }))

    return (
      <Drawer
        ref={drawerRef}
        title={
          <div className="flex flex-1 items-center justify-between gap-4 pr-3">
            <Typography variant="bodyHl" color="textSecondary" noWrap>
              {translate('text_1778836980285mhlwwvofsqm', {
                billableMetricName: displayName,
              })}
            </Typography>
            <Tooltip placement="bottom-end" title={translate('text_62d7f6178ec94cd09370e4b3')}>
              <Button
                variant="quaternary"
                icon="reload"
                onClick={async () => {
                  const updatedUsage = await refreshFunction?.()

                  setUsage(updatedUsage)
                }}
              />
            </Tooltip>
          </div>
        }
        stickyBottomBar={({ closeDrawer }) => (
          <Button size="medium" onClick={closeDrawer}>
            {translate('text_1726044816685r61awuydvji')}
          </Button>
        )}
      >
        <div className="mb-6">
          <Typography variant="headline">
            {translate('text_1778836980285mhlwwvofsqm', {
              billableMetricName: displayName,
            })}
          </Typography>
          <Typography>
            {translate('text_633dae57ca9a923dd53c2097', {
              fromDate: intlFormatDateTime(fromDatetime, {
                locale,
                timezone: customerTimezone,
              }).date,
              toDate: intlFormatDateTime(toDatetime, {
                locale,
                timezone: customerTimezone,
              }).date,
            })}
          </Typography>
        </div>

        <NavigationTab
          managedBy={TabManagedBy.INDEX}
          currentTab={activeTab}
          onChange={(index) => setActiveTab(index)}
          tabs={[
            {
              title: translate('text_1753094834414fgnvuior3iv'),
            },
            {
              title: translate('text_1753094834414tu9mxavuco7'),
            },
          ]}
        />

        <ChargeSummarySection
          usage={usage}
          currency={currency}
          locale={locale}
          showProjected={showProjected}
          translate={translate}
          unitsHeader={unitsHeader}
          amountHeader={amountHeader}
        />

        {showSection2 && (
          <section className="mt-12 flex flex-col gap-4">
            <Typography variant="subhead1" color="grey700">
              {translate('text_17786802483174e1d300blik')}
            </Typography>
            {!hasFiltersOrGroups && (
              <Alert type="info">{translate('text_17786802483175q57751skt9')}</Alert>
            )}
            {hasAnyFilterInGroupUsage && (
              <GroupedUsageWithFiltersTable
                usage={usage}
                currency={currency}
                locale={locale}
                showProjected={showProjected}
                translate={translate}
                unitsHeader={unitsHeader}
                amountHeader={amountHeader}
              />
            )}
            {!hasAnyFilterInGroupUsage && hasAnyUnitsInGroupUsage && (
              <GroupedUsageTable
                usage={usage}
                currency={currency}
                locale={locale}
                showProjected={showProjected}
                translate={translate}
                unitsHeader={unitsHeader}
                amountHeader={amountHeader}
              />
            )}
            {!hasAnyFilterInGroupUsage &&
              !hasAnyUnitsInGroupUsage &&
              (usage?.filters?.length ?? 0) > 0 && (
                <FiltersOnlyTable
                  usage={usage}
                  currency={currency}
                  locale={locale}
                  showProjected={showProjected}
                  translate={translate}
                  unitsHeader={unitsHeader}
                  amountHeader={amountHeader}
                />
              )}
          </section>
        )}
      </Drawer>
    )
  },
)

SubscriptionUsageDetailDrawer.displayName = 'SubscriptionUsageDetailDrawer'
