import { FC } from 'react'

import { useCustomLLMOutput } from '~/components/aiAgent/llmOutputs/hook'
import { ChatMessage, ChatStatus } from '~/hooks/aiAgent/aiAgentReducer'

interface MessageProps {
  message: ChatMessage
}

export const Message: FC<MessageProps> = ({ message }: MessageProps) => {
  const blockMatches = useCustomLLMOutput(message.message, message.status === ChatStatus.done)

  return blockMatches.map((blockMatch, index) => {
    const Component = blockMatch.block.component

    return <Component key={`llm-message-component-${index}`} blockMatch={blockMatch} />
  })
}
