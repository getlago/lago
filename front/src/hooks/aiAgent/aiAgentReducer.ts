export enum ChatRole {
  user = 'user',
  assistant = 'assistant',
}

export enum ChatStatus {
  pending = 'pending',
  streaming = 'streaming',
  done = 'done',
}

export enum ChatActionType {
  /**
   * Start a new conversation
   * with a user message and a pending response from assistant
   */
  START_CONVERSATION = 'START_CONVERSATION',
  /**
   * Stream a chunk with the assistant message
   */
  STREAMING = 'STREAMING',
  /**
   * Set the assistant message to done
   */
  DONE = 'DONE',
  /**
   * Add a new message to the conversation
   */
  ADD_INPUT = 'ADD_INPUT',
  /**
   * Reset the conversation
   */
  RESET_CONVERSATION = 'RESET_CONVERSATION',
  /**
   * Set the previous chat messages
   */
  SET_PREVIOUS_CHAT_MESSAGES = 'SET_PREVIOUS_CHAT_MESSAGES',
}

export type ChatMessage = {
  id: string
  role: ChatRole
  message: string
  status?: ChatStatus
}

export type ChatState = {
  messages: ChatMessage[]
  isLoading: boolean
  isStreaming: boolean
}

type ChatAction =
  | { type: ChatActionType.START_CONVERSATION; message: string }
  | { type: ChatActionType.STREAMING; messageId: string; chunk: string }
  | { type: ChatActionType.DONE; messageId: string }
  | { type: ChatActionType.ADD_INPUT; message: string }
  | { type: ChatActionType.RESET_CONVERSATION }
  | { type: ChatActionType.SET_PREVIOUS_CHAT_MESSAGES; messages: ChatMessage[] }

export const chatReducer = (state: ChatState, action: ChatAction): ChatState => {
  switch (action.type) {
    case ChatActionType.START_CONVERSATION: {
      const userMsg: ChatMessage = {
        id: crypto.randomUUID(),
        role: ChatRole.user,
        message: action.message,
        status: ChatStatus.done,
      }

      const assistantMsg: ChatMessage = {
        id: crypto.randomUUID(),
        role: ChatRole.assistant,
        message: '',
        status: ChatStatus.pending,
      }

      return {
        ...state,
        messages: [userMsg, assistantMsg],
        isStreaming: false,
        isLoading: true,
      }
    }

    case ChatActionType.STREAMING: {
      return {
        ...state,
        messages: state.messages.map((message) =>
          message.id === action.messageId
            ? {
                ...message,
                message: message.message + action.chunk,
                status: ChatStatus.streaming,
              }
            : message,
        ),
        isStreaming: true,
        isLoading: false,
      }
    }

    case ChatActionType.DONE: {
      return {
        ...state,
        messages: state.messages.map((message) =>
          message.id === action.messageId
            ? {
                ...message,
                status: ChatStatus.done,
              }
            : message,
        ),
        isStreaming: false,
        isLoading: false,
      }
    }

    case ChatActionType.ADD_INPUT: {
      const userMsg: ChatMessage = {
        id: crypto.randomUUID(),
        role: ChatRole.user,
        message: action.message,
        status: ChatStatus.done,
      }

      const assistantMsg: ChatMessage = {
        id: crypto.randomUUID(),
        role: ChatRole.assistant,
        message: '',
        status: ChatStatus.pending,
      }

      return {
        ...state,
        messages: [...state.messages, userMsg, assistantMsg],
        isLoading: true,
        isStreaming: false,
      }
    }

    case ChatActionType.RESET_CONVERSATION: {
      return {
        ...state,
        messages: [],
        isLoading: false,
        isStreaming: false,
      }
    }

    case ChatActionType.SET_PREVIOUS_CHAT_MESSAGES: {
      return {
        ...state,
        messages: action.messages,
        isLoading: false,
        isStreaming: false,
      }
    }

    default:
      return state
  }
}
