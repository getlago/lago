import { Button } from '~/components/designSystem/Button'
import { tw } from '~/styles/utils'

type TextButtonProps = {
  className?: string
  onClick: () => void
  content: string
}

const TextButton = ({ className, content, onClick }: TextButtonProps) => (
  <Button
    className={tw(
      '-ml-2 h-auto px-2 py-0 text-blue-600 hover:!bg-white hover:text-blue-700',
      className,
    )}
    variant="quaternary"
    onClick={onClick}
  >
    {content}
  </Button>
)

export default TextButton
