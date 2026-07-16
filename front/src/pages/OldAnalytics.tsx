import { Icon } from 'lago-design-system'
import { useEffect, useMemo, useState } from 'react'

import { AnalyticsStateProvider } from '~/components/analytics/AnalyticsStateContext'
import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { TextInput } from '~/components/form'
import Gross from '~/components/graphs/Gross'
import Invoices from '~/components/graphs/Invoices'
import MonthSelectorDropdown, {
  AnalyticsPeriodScopeEnum,
  TPeriodScopeTranslationLookupValue,
} from '~/components/graphs/MonthSelectorDropdown'
import Mrr from '~/components/graphs/Mrr'
import Overview from '~/components/graphs/Overview'
import Usage from '~/components/graphs/Usage'
import { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { MenuPopper, PageHeader } from '~/styles'

const Analytics = () => {
  const { translate } = useInternationalization()
  const { isPremium, currentUser, loading: currentUserDataLoading } = useCurrentUser()
  const { organization, loading: currentOrganizationDataLoading } = useOrganizationInfos()
  const { open: openPremiumWarningDialog } = usePremiumWarningDialog()

  const [periodScope, setPeriodScope] = useState<TPeriodScopeTranslationLookupValue>(
    AnalyticsPeriodScopeEnum.Year,
  )
  const [currencySearch, setCurrencySearch] = useState<string>('')
  const [selectedCurrency, setSelectedCurrency] = useState<CurrencyEnum | undefined>(
    organization?.defaultCurrency || CurrencyEnum.Usd,
  )

  useEffect(() => {
    if (!currentOrganizationDataLoading && organization?.defaultCurrency) {
      setSelectedCurrency(organization?.defaultCurrency)
    }
  }, [currentOrganizationDataLoading, organization?.defaultCurrency])

  const currenciesToDisplay = useMemo(() => {
    return Object.values(CurrencyEnum).filter((c) =>
      c.toLowerCase().includes(currencySearch.toLowerCase()),
    )
  }, [currencySearch])

  return (
    <>
      <PageHeader.Wrapper withSide>
        <Typography variant="bodyHl" color="grey700" noWrap>
          {translate('text_6553885df387fd0097fd7384')}
        </Typography>

        <PageHeader.Group>
          <Popper
            maxHeight={452}
            PopperProps={{ placement: 'bottom-end' }}
            opener={({ isOpen }) => (
              <Button
                onClick={() => {
                  if (isOpen) {
                    setCurrencySearch('')
                  } else {
                    setTimeout(() => {
                      const currencyButton = document.querySelector(
                        `[data-analytics-currency="${selectedCurrency}"]`,
                      )

                      if (currencyButton) {
                        currencyButton.scrollIntoView({
                          behavior: 'instant',
                          block: 'start',
                          inline: 'start',
                        })
                      }
                    }, 0)
                  }
                }}
                variant="inline"
                endIcon={'chevron-down'}
              >
                {selectedCurrency}
              </Button>
            )}
            onClickAway={() => {
              setCurrencySearch('')
            }}
          >
            {({ closePopper }) => (
              <MenuPopper className="flex flex-col gap-4 p-4">
                <div className="sticky top-4 mb-4 bg-white">
                  <TextInput
                    className="max-w-50 [&_input]:h-12 [&_input]:!pl-3"
                    id="search-currency-input"
                    placeholder="Search a currency"
                    onChange={(value) => {
                      setCurrencySearch(value)
                    }}
                    InputProps={{
                      startAdornment: <Icon className="ml-4" name="magnifying-glass" />,
                    }}
                  />
                </div>
                <div className="flex max-h-89 flex-col gap-1 overflow-y-auto rounded-xl border border-grey-300 p-4">
                  {!currenciesToDisplay.length ? (
                    <Typography className="p-[6px]" variant="body" color="disabled">
                      {translate('text_65562fd544bc8a0057706172')}
                    </Typography>
                  ) : (
                    <>
                      {currenciesToDisplay.map((localCurrency) => (
                        <Button
                          key={localCurrency}
                          className="scroll-m-1"
                          variant={selectedCurrency === localCurrency ? 'secondary' : 'quaternary'}
                          align="left"
                          data-analytics-currency={localCurrency}
                          onClick={() => {
                            setSelectedCurrency(localCurrency)
                            closePopper()
                            setCurrencySearch('')
                          }}
                        >
                          {localCurrency}
                          {localCurrency === organization?.defaultCurrency &&
                            ` ${translate('text_6556304dcd49290089c3cfe1')}`}
                        </Button>
                      ))}
                    </>
                  )}
                </div>
              </MenuPopper>
            )}
          </Popper>
          <MonthSelectorDropdown periodScope={periodScope} setPeriodScope={setPeriodScope} />
        </PageHeader.Group>
      </PageHeader.Wrapper>

      {!isPremium && !!currentUser && (
        <div className="flex min-h-37 items-center justify-between gap-4 bg-yellow-100 p-12">
          <div className="flex flex-col">
            <div className="flex items-center gap-2">
              <Typography variant="bodyHl" color="grey700">
                {translate('text_6556309ded468200b9debbd4')}
              </Typography>
              <Icon name="sparkles" />
            </div>
            <Typography variant="caption" color="grey600">
              {translate('text_6556309ded468200b9debbd5')}
            </Typography>
          </div>

          <Button
            variant="tertiary"
            endIcon="sparkles"
            onClick={() => {
              openPremiumWarningDialog()
            }}
          >
            {translate('text_65ae73ebe3a66bec2b91d72d')}
          </Button>
        </div>
      )}

      <div className="mx-4 my-12 grid grid-cols-[1fr] gap-px bg-grey-300 md:m-12 lg:grid-cols-[1fr_1fr]">
        <AnalyticsStateProvider>
          <Overview currency={selectedCurrency} period={periodScope} />
        </AnalyticsStateProvider>
        <AnalyticsStateProvider>
          <Gross className="lg:pr-6" currency={selectedCurrency} period={periodScope} />
        </AnalyticsStateProvider>
        <AnalyticsStateProvider>
          <Mrr
            blur={!isPremium || !currentUser}
            className="lg:pl-6"
            currency={selectedCurrency}
            demoMode={!isPremium || !currentUser}
            forceLoading={currentUserDataLoading || currentOrganizationDataLoading}
            period={periodScope}
          />
        </AnalyticsStateProvider>
        <Usage
          demoMode={!isPremium || !currentUser}
          className="lg:pr-6"
          blur={!isPremium || !currentUser}
          currency={selectedCurrency}
          forceLoading={currentUserDataLoading || currentOrganizationDataLoading}
          period={periodScope}
        />
        <Invoices
          demoMode={!isPremium || !currentUser}
          className="lg:pl-6"
          blur={!isPremium || !currentUser}
          currency={selectedCurrency}
          forceLoading={currentUserDataLoading || currentOrganizationDataLoading}
          period={periodScope}
        />
      </div>
    </>
  )
}

export default Analytics
