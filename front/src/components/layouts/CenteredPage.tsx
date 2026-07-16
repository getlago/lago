import { tw } from 'lago-design-system'
import { PropsWithChildren } from 'react'

import { Typography } from '~/components/designSystem/Typography'

// Test ID constants
export const PAGE_SECTION_TITLE_TEST_ID = 'page-section-title'
export const PAGE_SECTION_TITLE_DESCRIPTION_TEST_ID = 'page-section-title-description'
export const SUBSECTION_TITLE_TEST_ID = 'subsection-title'
export const SUBSECTION_TITLE_DESCRIPTION_TEST_ID = 'subsection-title-description'

export const PageBannerHeaderWithBurgerMenu = ({ children }: PropsWithChildren) => {
  return (
    <header className="sticky top-0 z-navBar flex h-nav items-center justify-between gap-2 bg-white px-17 shadow-b md:px-12">
      {children}
    </header>
  )
}

const CenteredPageWrapper = ({ children }: PropsWithChildren) => {
  return (
    <div
      className="flex size-full min-h-full flex-col overflow-auto bg-white"
      data-centered-page-wrapper
    >
      {children}
    </div>
  )
}

const PageBannerHeader = ({ children }: PropsWithChildren) => {
  return (
    <header className="sticky top-0 z-navBar flex h-nav items-center justify-between gap-2 bg-white p-4 shadow-b md:px-12">
      {children}
    </header>
  )
}

const CenteredContainer = ({ className, children }: PropsWithChildren & { className?: string }) => {
  return (
    <div
      className={tw(
        'mx-auto flex w-full max-w-170 flex-1 flex-col gap-12 px-4 pb-footer pt-12 md:px-0',
        className,
      )}
    >
      {children}
    </div>
  )
}

const CenteredStickyFooter = ({ children }: PropsWithChildren) => {
  return (
    <footer className="sticky bottom-0 z-navBar w-full bg-white shadow-t">
      <div className="mx-auto flex min-h-footer w-full max-w-170 flex-wrap-reverse items-center justify-end gap-3 px-4 md:px-0">
        {children}
      </div>
    </footer>
  )
}

const PageTitle = ({ title, description }: { title: string; description?: string }) => {
  return (
    <div className="flex flex-col gap-1">
      <Typography variant="headline" color="textSecondary">
        {title}
      </Typography>
      <Typography variant="body">{description}</Typography>
    </div>
  )
}

const PageSectionTitle = ({
  title,
  description,
}: {
  title: string
  description?: string | JSX.Element
}) => {
  return (
    <div className="flex flex-col gap-2" data-test={PAGE_SECTION_TITLE_TEST_ID}>
      <Typography variant="subhead1" color="grey700">
        {title}
      </Typography>
      {description &&
        (typeof description === 'string' ? (
          <Typography
            variant="caption"
            color="grey600"
            data-test={PAGE_SECTION_TITLE_DESCRIPTION_TEST_ID}
          >
            {description}
          </Typography>
        ) : (
          description
        ))}
    </div>
  )
}

const SubsectionTitle = ({
  title,
  description,
}: {
  title: string
  description?: string | JSX.Element
}) => {
  return (
    <div className="flex flex-col gap-1" data-test={SUBSECTION_TITLE_TEST_ID}>
      <Typography variant="captionHl" color="grey700">
        {title}
      </Typography>
      {description &&
        (typeof description === 'string' ? (
          <Typography
            variant="caption"
            color="grey600"
            data-test={SUBSECTION_TITLE_DESCRIPTION_TEST_ID}
          >
            {description}
          </Typography>
        ) : (
          description
        ))}
    </div>
  )
}

const PageSection = ({ children }: PropsWithChildren) => {
  return <section className="flex flex-col gap-6">{children}</section>
}

const SectionWrapper = ({ children }: PropsWithChildren) => (
  <div className="flex flex-col gap-12">{children}</div>
)

const SubsectionWrapper = ({ children }: PropsWithChildren) => (
  <div className="flex flex-col not-last-child:mb-12 not-last-child:pb-12 not-last-child:shadow-b">
    {children}
  </div>
)

export const CenteredPage = {
  Wrapper: CenteredPageWrapper,
  Header: PageBannerHeader,
  HeaderWithBurgerMenu: PageBannerHeaderWithBurgerMenu,
  Container: CenteredContainer,
  StickyFooter: CenteredStickyFooter,
  PageSection,
  PageSectionTitle,
  PageTitle,
  SectionWrapper,
  SubsectionTitle,
  SubsectionWrapper,
}
