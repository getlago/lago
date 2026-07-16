import { useState } from 'react'

import { ChatConversation } from '~/components/aiAgent/ChatConversation'
import { ChatMessages } from '~/components/aiAgent/ChatMessages'
import { ChatPromptEditor } from '~/components/aiAgent/ChatPromptEditor'
import { ChatShortcuts } from '~/components/aiAgent/ChatShortcuts'
import { useCreateAiConversation } from '~/components/aiAgent/hooks/useCreateAiConversation'
import { useOnConversation } from '~/components/aiAgent/hooks/useOnConversation'
import { Typography } from '~/components/designSystem/Typography'
import PremiumFeature from '~/components/premium/PremiumFeature'
import { CreateAiConversationInput } from '~/generated/graphql'
import { useAiAgent } from '~/hooks/aiAgent/useAiAgent'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type PanelAiAgentProps = {
  hasAccessToAiAgent: boolean
}

export const PanelAiAgent = ({ hasAccessToAiAgent }: PanelAiAgentProps) => {
  const { conversationId, state, startNewConversation, addNewMessage } = useAiAgent()
  const { createAiConversation, loading, error } = useCreateAiConversation()
  const [initialPrompt, setInitialPrompt] = useState<string>('')
  const { translate } = useInternationalization()

  const subscription = useOnConversation({
    conversationId,
  })

  const handleSubmit = async (values: CreateAiConversationInput) => {
    setInitialPrompt(values.message)

    await createAiConversation({
      variables: {
        input: {
          message: values.message,
          conversationId: conversationId || undefined,
        },
      },

      onCompleted: (data) => {
        if (conversationId) {
          addNewMessage(values.message)

          return subscription.restart()
        }

        if (!data.createAiConversation?.id) {
          return
        }

        return startNewConversation({
          convId: data.createAiConversation.id,
          message: values.message,
        })
      },
    })
  }

  const shouldDisplayWelcomeMessage = !state.messages.length && !loading && !error

  return (
    <div className="flex h-full flex-col bg-grey-100 shadow-l">
      {shouldDisplayWelcomeMessage && (
        <div className="mb-6 mt-auto flex flex-col gap-6 px-6">
          <div className="flex flex-col gap-1">
            <Typography variant="headline" color="grey700">
              {translate('text_1757417225851l83ffyzwk4g')}
            </Typography>
            <Typography variant="body" color="grey600">
              {translate('text_1757417225851ylz6l7fwrg9')}
            </Typography>
          </div>

          {hasAccessToAiAgent && <ChatShortcuts onSubmit={handleSubmit} />}
        </div>
      )}

      {!hasAccessToAiAgent && (
        <div className="p-6 pt-0">
          <PremiumFeature
            title={translate('text_1765530128923vobffyisvq9')}
            description={translate('text_176553012892493ck00lv7qj')}
            feature="Lago AI Agent"
            className="flex-col border border-grey-300 bg-white"
            buttonClassName="self-end"
          />
        </div>
      )}

      {!shouldDisplayWelcomeMessage && !state.messages.length && initialPrompt && !error && (
        <div className="mt-auto flex h-full flex-col gap-12 p-6">
          <ChatMessages.Sent>{initialPrompt}</ChatMessages.Sent>

          <ChatMessages.Loading />
        </div>
      )}

      {!!state.messages.length && <ChatConversation subscription={subscription} />}

      <ChatPromptEditor disabled={!hasAccessToAiAgent} onSubmit={handleSubmit} />
    </div>
  )
}
