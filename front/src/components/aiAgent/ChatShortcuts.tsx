import { Button } from '~/components/designSystem/Button'
import { CreateAiConversationInput } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

const shortcuts = [
  {
    id: 'revenue-insights',
    label: 'text_1757425256010tqrmn1nv7hv',
    value: 'text_1757425256010w5kf0uv78o0',
  },
  {
    id: 'promotions-adjustments',
    label: 'text_1757425256010vk3j5uvsv8j',
    value: 'text_17574252560106dd3b4zgpor',
  },
  {
    id: 'customer-management',
    label: 'text_1757425256010rkgdjdrjk6m',
    value: 'text_1757425256010xzjeae40r11',
  },
  {
    id: 'pricing-packages',
    label: 'text_1757425256010ibchc292e3s',
    value: 'text_1757425256010x3su3naky6p',
  },
  {
    id: 'billing-collections',
    label: 'text_1757425256010zsl6bjv4hyi',
    value: 'text_175742525601015r0mf0b8a4',
  },
  {
    id: 'subscriptions-usage',
    label: 'text_1757425256010fv461mpya3w',
    value: 'text_1757425256010h97y71qmabf',
  },
]

export const ChatShortcuts = ({
  onSubmit,
}: {
  onSubmit: (values: CreateAiConversationInput) => void
}) => {
  const { translate } = useInternationalization()

  return (
    <div className="flex flex-wrap gap-2">
      {shortcuts.map((shortcut) => (
        <Button
          className="bg-white"
          key={shortcut.id}
          variant="tertiary"
          size="small"
          onClick={() => onSubmit({ message: translate(shortcut.value) })}
        >
          {translate(shortcut.label)}
        </Button>
      ))}
    </div>
  )
}
