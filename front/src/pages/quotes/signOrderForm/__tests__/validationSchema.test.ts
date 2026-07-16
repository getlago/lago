import { DateTime } from 'luxon'

import { OrderExecutionModeEnum } from '~/generated/graphql'

import { buildSignOrderFormInput, signOrderFormValidationSchema } from '../validationSchema'

const futureDate = DateTime.now().plus({ days: 7 }).toISO() as string
const today = DateTime.now().toISO() as string
const pastDate = DateTime.now().minus({ days: 7 }).toISO() as string

describe('signOrderFormValidationSchema', () => {
  it('fails when execution mode and date are missing', () => {
    expect(signOrderFormValidationSchema.safeParse({}).success).toBe(false)
  })

  it('passes when execution mode and a future date are present', () => {
    expect(
      signOrderFormValidationSchema.safeParse({
        executionMode: OrderExecutionModeEnum.ExecuteInLago,
        executeAt: futureDate,
      }).success,
    ).toBe(true)
  })

  it('fails when the execution date is today', () => {
    const result = signOrderFormValidationSchema.safeParse({
      executionMode: OrderExecutionModeEnum.ExecuteInLago,
      executeAt: today,
    })

    expect(result.success).toBe(false)
    expect(
      !result.success && result.error.issues.some((issue) => issue.path.includes('executeAt')),
    ).toBe(true)
  })

  it('fails when the execution date is in the past', () => {
    expect(
      signOrderFormValidationSchema.safeParse({
        executionMode: OrderExecutionModeEnum.ExecuteInLago,
        executeAt: pastDate,
      }).success,
    ).toBe(false)
  })
})

describe('buildSignOrderFormInput', () => {
  it('maps form values to the mutation input', () => {
    expect(
      buildSignOrderFormInput('of-1', {
        executionMode: OrderExecutionModeEnum.OrderOnly,
        executeAt: '2026-07-01',
        signedDocument: 'data:application/pdf;base64,AAAA',
      }),
    ).toEqual({
      id: 'of-1',
      executionMode: OrderExecutionModeEnum.OrderOnly,
      executeAt: '2026-07-01',
      signedDocument: 'data:application/pdf;base64,AAAA',
    })
  })

  it('omits signedDocument when empty', () => {
    expect(
      buildSignOrderFormInput('of-1', {
        executionMode: OrderExecutionModeEnum.ExecuteInLago,
        executeAt: '2026-07-01',
        signedDocument: undefined,
      }),
    ).toEqual({
      id: 'of-1',
      executionMode: OrderExecutionModeEnum.ExecuteInLago,
      executeAt: '2026-07-01',
      signedDocument: undefined,
    })
  })
})
