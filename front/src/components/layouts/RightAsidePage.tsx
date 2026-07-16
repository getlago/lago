import { Button } from '../designSystem/Button'

export const RIGHT_ASIDE_PAGE_HEADER_TEST_ID = 'right-aside-page-header'
export const RIGHT_ASIDE_PAGE_HEADER_DIVIDER_TEST_ID = 'right-aside-page-header-divider'

const Wrapper = ({ children }: { children: React.ReactNode }) => {
  return <div className="flex h-full flex-col">{children}</div>
}

type ContentProps = {
  children: React.ReactNode
  aside: React.ReactNode
}

const Content = ({ children, aside }: ContentProps) => {
  return (
    <div className="flex flex-1 flex-row overflow-hidden">
      <div className="flex-1 overflow-auto">{children}</div>
      <div className="w-[400px] shrink-0 overflow-auto border-l border-grey-300">{aside}</div>
    </div>
  )
}

type HeaderProps = {
  children?: React.ReactNode
  title: React.ReactNode
  onClose: () => void
  isCloseButtonDisabled?: boolean
}

type SubheaderProps = {
  children?: React.ReactNode
}

const Header = ({ title, onClose, children, isCloseButtonDisabled }: HeaderProps) => {
  return (
    <div
      className="flex flex-row items-center justify-between gap-4 px-12 py-3 shadow-b"
      data-test={RIGHT_ASIDE_PAGE_HEADER_TEST_ID}
    >
      {title}
      <div className="flex flex-row items-center gap-3">
        {children}
        {children && (
          <div
            className="h-10 border-l border-grey-300"
            data-test={RIGHT_ASIDE_PAGE_HEADER_DIVIDER_TEST_ID}
          />
        )}
        <Button
          variant="quaternary"
          icon="close"
          onClick={onClose}
          disabled={isCloseButtonDisabled}
        />
      </div>
    </div>
  )
}

const SubHeader = ({ children }: SubheaderProps) => {
  return (
    <div className="flex flex-row items-center justify-between gap-4 px-12 py-3 shadow-b">
      {children}
    </div>
  )
}

export const RightAsidePage = {
  Wrapper,
  Header,
  SubHeader,
  Content,
}
