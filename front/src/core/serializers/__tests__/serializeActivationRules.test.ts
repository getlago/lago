import { ActivationRuleFormTypeEnum } from '~/core/constants/subscriptionActivationRules'
import { ActivationRuleTypeEnum } from '~/generated/graphql'

import { deserializeActivationRules, serializeActivationRules } from '../serializeActivationRules'

describe('serializeActivationRules', () => {
  it('returns an empty array when activation is immediate', () => {
    expect(
      serializeActivationRules({
        activationRuleType: ActivationRuleFormTypeEnum.Immediately,
        activationRuleTimeoutHours: '48',
      }),
    ).toEqual([])
  })

  it('serializes payment activation with timeout hours', () => {
    expect(
      serializeActivationRules({
        activationRuleType: ActivationRuleFormTypeEnum.OnPayment,
        activationRuleTimeoutHours: '0',
      }),
    ).toEqual([
      {
        type: ActivationRuleTypeEnum.Payment,
        timeoutHours: 0,
      },
    ])
  })

  it('omits timeoutHours when the value is empty', () => {
    expect(
      serializeActivationRules({
        activationRuleType: ActivationRuleFormTypeEnum.OnPayment,
        activationRuleTimeoutHours: '',
      }),
    ).toEqual([
      {
        type: ActivationRuleTypeEnum.Payment,
      },
    ])
  })

  it('omits timeoutHours when the value is null', () => {
    expect(
      serializeActivationRules({
        activationRuleType: ActivationRuleFormTypeEnum.OnPayment,
        activationRuleTimeoutHours: null,
      }),
    ).toEqual([
      {
        type: ActivationRuleTypeEnum.Payment,
      },
    ])
  })
})

describe('deserializeActivationRules', () => {
  it('returns immediate activation when no payment rule exists', () => {
    expect(deserializeActivationRules([])).toEqual({
      activationRuleType: ActivationRuleFormTypeEnum.Immediately,
      activationRuleTimeoutHours: '24',
    })
  })

  it('hydrates the payment activation rule', () => {
    expect(
      deserializeActivationRules([
        {
          type: ActivationRuleTypeEnum.Payment,
          timeoutHours: 72,
        },
      ]),
    ).toEqual({
      activationRuleType: ActivationRuleFormTypeEnum.OnPayment,
      activationRuleTimeoutHours: '72',
    })
  })

  it('hydrates a payment activation rule with a null timeout as an empty value', () => {
    expect(
      deserializeActivationRules([
        {
          type: ActivationRuleTypeEnum.Payment,
          timeoutHours: null,
        },
      ]),
    ).toEqual({
      activationRuleType: ActivationRuleFormTypeEnum.OnPayment,
      activationRuleTimeoutHours: '',
    })
  })
})
