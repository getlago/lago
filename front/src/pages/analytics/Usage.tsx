import UsageBreakdownSection from '~/components/analytics/usage/UsageBreakdownSection'
import UsageOverviewSection from '~/components/analytics/usage/UsageOverviewSection'
import { FullscreenPage } from '~/components/layouts/FullscreenPage'

const Usage = () => {
  return (
    <FullscreenPage.Wrapper>
      <UsageOverviewSection />

      <UsageBreakdownSection />
    </FullscreenPage.Wrapper>
  )
}

export default Usage
