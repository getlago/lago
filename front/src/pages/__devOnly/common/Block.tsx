import { tw } from 'lago-design-system'

const Block = ({ children, className }: { children: React.ReactNode; className?: string }) => (
  <div className={tw('mb-6 flex flex-col flex-wrap gap-4', className)}>{children}</div>
)

export default Block
