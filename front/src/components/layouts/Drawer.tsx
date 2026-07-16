import { FC, PropsWithChildren } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import { tw } from '~/styles/utils'

const Wrapper: FC<PropsWithChildren<{ className?: string }>> = ({ children, className }) => (
  <div className={tw('flex min-h-full w-full flex-col bg-white', className)}>{children}</div>
)

const Content: FC<PropsWithChildren> = ({ children }) => (
  <div className={tw('flex w-full flex-1 flex-col gap-12 px-4 py-12 md:px-12')}>{children}</div>
)

const Header: FC<{ title: string; description: string }> = ({ description, title }) => {
  return (
    <header className="flex flex-col gap-1">
      <Typography variant="headline" color="grey700">
        {title}
      </Typography>
      <Typography variant="body" color="grey600">
        {description}
      </Typography>
    </header>
  )
}

const Section: FC<PropsWithChildren> = ({ children }) => {
  return (
    <section className="flex flex-col gap-6 not-last:pb-12 not-last:shadow-b">{children}</section>
  )
}

const SectionTitle: FC<{ title: string; description: string }> = ({ description, title }) => {
  return (
    <div className="flex flex-col gap-2">
      <Typography variant="subhead1" color="grey700">
        {title}
      </Typography>
      <Typography variant="caption" color="grey600">
        {description}
      </Typography>
    </div>
  )
}

const StickyFooter: FC<PropsWithChildren> = ({ children }) => {
  return (
    <footer className="sticky bottom-0 z-navBar w-full bg-white shadow-t">
      <div className="flex min-h-footer w-full flex-row flex-wrap-reverse items-center justify-end gap-3 px-4 md:px-12">
        {children}
      </div>
    </footer>
  )
}

export const DrawerLayout = {
  Wrapper,
  Content,
  Header,
  Section,
  SectionTitle,
  StickyFooter,
}
