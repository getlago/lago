import { evaluateExpression, parseExpression } from 'lago-expression'

import { EventPayload, ValidationResult } from '~/components/billableMetrics/CustomExpressionDrawer'
import { TranslateFunc } from '~/hooks/core/useInternationalization'

const REQUIRED_EVENT_FIELDS: Array<keyof EventPayload['event']> = [
  'code',
  'timestamp',
  'properties',
]

export const wrappedEvaluateExpression = (
  expression: string,
  payload: EventPayload,
  translate: TranslateFunc,
): ValidationResult => {
  try {
    let eventPayload = payload

    if (typeof payload === 'string') {
      eventPayload = JSON.parse(payload)
    }

    REQUIRED_EVENT_FIELDS.forEach((property) => {
      if (!eventPayload?.event?.[property]) {
        throw new Error(
          translate('text_17326923760161haoak0v6km', {
            property,
          }),
        )
      }
    })

    const res = evaluateExpression(
      parseExpression(expression),
      eventPayload.event.code,
      BigInt(eventPayload.event.timestamp),
      eventPayload.event.properties,
    )

    return {
      result: res,
    }
  } catch (e) {
    return {
      error: String(e),
    }
  }
}

export const wrappedParseExpression = (expression?: string | null): boolean => {
  if (!expression) {
    return false
  }

  try {
    parseExpression(expression)

    return true
  } catch {
    return false
  }
}

export const isValidJSON = (json?: unknown) => {
  if (!json) {
    return false
  }

  try {
    if (typeof json === 'object') {
      return true
    }

    if (typeof json === 'string') {
      JSON.parse(json)
    }

    return true
  } catch {
    return false
  }
}
