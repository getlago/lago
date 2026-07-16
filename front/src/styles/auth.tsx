import { FC, PropsWithChildren } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import Logo from '~/public/images/logo/lago-logo.svg'

import { tw } from './utils'

export const Page: FC<PropsWithChildren> = ({ children }) => (
  <div className="flex min-h-screen items-start justify-center bg-grey-100 p-4 md:items-center">
    {children}
  </div>
)

export const StyledLogo: FC<React.SVGProps<SVGSVGElement>> = (props) => (
  <Logo className="mb-12" {...props} />
)

export const Card: FC<
  PropsWithChildren & {
    className?: string
  }
> = ({ children, className, ...props }) => (
  <div className={tw('w-full max-w-144 rounded-xl bg-white p-10 shadow-md', className)} {...props}>
    {children}
  </div>
)

export const Title: FC<PropsWithChildren> = ({ children }) => (
  <Typography className="mb-3" variant="headline">
    {children}
  </Typography>
)

export const Subtitle: FC<PropsWithChildren<{ noMargins?: boolean }>> = ({
  children,
  noMargins,
}) => <Typography className={tw('mb-8', { '!mb-0': !!noMargins })}>{children}</Typography>
