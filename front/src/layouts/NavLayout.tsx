import { tw } from 'lago-design-system'
import { forwardRef, PropsWithChildren } from 'react'

import { Button } from '~/components/designSystem/Button'

const NavWrapper = ({ children }: PropsWithChildren) => {
  return <div className="flex h-screen w-full">{children}</div>
}

// Need to accept ref cause it's used within a ClickAwayListener
const Nav = forwardRef<HTMLElement, PropsWithChildren<{ isOpen: boolean; className?: string }>>(
  ({ children, className, isOpen }, ref) => {
    return (
      <nav
        ref={ref}
        className={tw(
          'absolute z-sideNav box-content flex h-full w-60 flex-col overflow-auto border-r border-grey-300 bg-white transition-[left] duration-250 md:static md:left-auto md:z-auto',
          isOpen ? 'left-0' : '-left-60',
          className,
        )}
      >
        {children}
      </nav>
    )
  },
)

Nav.displayName = 'Nav'

const NavBurgerButton = ({
  onClick,
  'data-test': dataTest,
}: {
  onClick: () => void
  'data-test'?: string
}) => {
  return (
    <Button
      {...(dataTest ? { 'data-test': dataTest } : {})}
      className="absolute left-4 top-2 z-drawer !w-[36px] !bg-white !p-[10px] md:hidden"
      icon="burger"
      variant="quaternary"
      onClick={(e) => {
        e.stopPropagation()
        onClick()
      }}
    />
  )
}

const NavStickyElementContainer = ({
  children,
  'data-test': dataTest,
}: PropsWithChildren<{ 'data-test'?: string }>) => {
  return (
    <div
      className="sticky left-0 top-0 z-sideNav flex h-29 w-60 items-end bg-white p-4 animate-shadow-bottom md:h-nav"
      data-test={dataTest}
    >
      {children}
    </div>
  )
}

const NavSectionGroup = ({
  children,
  'data-test': dataTest,
}: PropsWithChildren<{ 'data-test'?: string }>) => {
  return (
    <div className="flex flex-1 flex-col gap-4 px-4" data-test={dataTest}>
      {children}
    </div>
  )
}

const NavSection = ({
  children,
  className,
  'data-test': dataTest,
}: PropsWithChildren<{ className?: string; 'data-test'?: string }>) => {
  return (
    <div className={tw('flex w-full flex-col gap-1', className)} data-test={dataTest}>
      {children}
    </div>
  )
}

const ContentWrapper = forwardRef<HTMLDivElement, PropsWithChildren<{ 'data-test'?: string }>>(
  ({ children, 'data-test': dataTest }, ref) => {
    return (
      <div className="flex-1 overflow-y-auto" ref={ref} data-test={dataTest}>
        {children}
      </div>
    )
  },
)

ContentWrapper.displayName = 'ContentWrapper'

export const NavLayout = {
  ContentWrapper,
  Nav,
  NavBurgerButton,
  NavSection,
  NavSectionGroup,
  NavStickyElementContainer,
  NavWrapper,
}
