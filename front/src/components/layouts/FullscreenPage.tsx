import { FC, PropsWithChildren } from 'react'

const Wrapper: FC<PropsWithChildren> = ({ children }) => {
  return <div className="flex w-full flex-col gap-12 px-4 py-12 md:p-12">{children}</div>
}

export const FullscreenPage = {
  Wrapper,
}
