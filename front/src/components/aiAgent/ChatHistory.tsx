import { DateTime } from 'luxon'

import { useGetAiConversation } from '~/components/aiAgent/hooks/getAiConversation'
import { useListAiConversations } from '~/components/aiAgent/hooks/listAiConversations'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { ChatRole, ChatStatus } from '~/hooks/aiAgent/aiAgentReducer'
import { useAiAgent } from '~/hooks/aiAgent/useAiAgent'
import { tw } from '~/styles/utils'

type ChatHistoryProps = {
  hideHistory?: () => void
}

export const ChatHistory = ({ hideHistory }: ChatHistoryProps) => {
  const { setPreviousChatMessages } = useAiAgent()

  const { getAiConversation } = useGetAiConversation()

  const { data, loading, error } = useListAiConversations()

  const handleGetAiConversation = async (id: string) => {
    const { data: singleConversationData } = await getAiConversation({
      variables: {
        id,
      },
    })

    if (singleConversationData?.aiConversation?.id) {
      const formattedMessages = singleConversationData?.aiConversation?.messages?.map((message) => {
        const randomKey = crypto.randomUUID()

        return {
          id: `${message.type}-${randomKey}`,
          role: message.type === 'message.input' ? ChatRole.user : ChatRole.assistant,
          message: message.content,
          status: ChatStatus.done,
        }
      })

      hideHistory?.()

      setPreviousChatMessages({
        convId: singleConversationData?.aiConversation.id,
        messages: formattedMessages ?? [],
      })
    }
  }

  if (error) {
    return null
  }

  return (
    <div className="flex h-full flex-col gap-1 bg-grey-100 p-4 pt-6">
      <div className="flex flex-col gap-1">
        {loading &&
          Array.from({ length: 3 }).map((_, index) => (
            <div key={index} className="flex items-center justify-between gap-2">
              <Skeleton variant="text" className="w-60" />
              <Skeleton variant="text" className="w-24" />
            </div>
          ))}

        {!loading &&
          data?.aiConversations?.collection.map((conversation, index) => (
            <div
              key={conversation.id}
              className={tw(
                'flex items-center justify-between gap-2 py-3',
                index === (data?.aiConversations?.collection?.length || 0) - 1 ? '' : 'shadow-b',
              )}
            >
              <button
                onClick={() => handleGetAiConversation(conversation.id)}
                className="text-left"
              >
                <Typography variant="caption" className="justify-start" color="grey600">
                  {conversation.name}
                </Typography>
              </button>

              <Typography
                noWrap
                variant="caption"
                color="grey600"
                className="inline-block min-h-7 shrink-0 rounded-lg border border-grey-400 bg-white px-2"
              >
                {DateTime.fromISO(conversation.updatedAt)
                  .toRelative({
                    locale: 'en-US',
                    style: 'short',
                  })
                  ?.replace('ago', '')
                  ?.replace('.', '')
                  ?.replace(' ', '')}
              </Typography>
            </div>
          ))}
      </div>
    </div>
  )
}
