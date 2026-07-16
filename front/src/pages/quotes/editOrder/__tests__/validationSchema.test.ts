import { DateTime } from 'luxon'

import { OrderExecutionModeEnum } from '~/generated/graphql'

import { buildUpdateOrderInput, editOrderValidationSchema } from '../validationSchema'

describe('editOrderValidationSchema', () => {
  it('rejects when executionMode is missing', () => {
    const result = editOrderValidationSchema.safeParse({ executeAt: undefined })

    expect(result.success).toBe(false)
  })

  it('accepts a valid executionMode with no executeAt', () => {
    const result = editOrderValidationSchema.safeParse({
      executionMode: OrderExecutionModeEnum.ExecuteInLago,
    })

    expect(result.success).toBe(true)
  })

  it('rejects an executeAt that is today or in the past', () => {
    const today = DateTime.now().startOf('day').toISO() as string
    const result = editOrderValidationSchema.safeParse({
      executionMode: OrderExecutionModeEnum.ExecuteInLago,
      executeAt: today,
    })

    expect(result.success).toBe(false)
  })

  it('accepts an executeAt in the future', () => {
    const future = DateTime.now().plus({ days: 2 }).toISO() as string
    const result = editOrderValidationSchema.safeParse({
      executionMode: OrderExecutionModeEnum.ExecuteInLago,
      executeAt: future,
    })

    expect(result.success).toBe(true)
  })
})

describe('buildUpdateOrderInput', () => {
  it('maps order id and form values to the mutation input', () => {
    expect(
      buildUpdateOrderInput('order-1', {
        executionMode: OrderExecutionModeEnum.OrderOnly,
        executeAt: '2030-01-01T00:00:00.000Z',
      }),
    ).toEqual({
      id: 'order-1',
      executionMode: OrderExecutionModeEnum.OrderOnly,
      executeAt: '2030-01-01T00:00:00.000Z',
    })
  })
})
