import { FC, ReactElement } from 'react'

const InfoRow: FC<{ children: React.ReactNode }> = ({ children }): ReactElement => (
  <div className="mb-2 flex gap-4 first-child:w-50 first-child:shrink-0">{children}</div>
)

export { InfoRow }
