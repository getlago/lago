import formatCreditNotesItems from '~/core/formats/formatCreditNotesItems'
import { CurrencyEnum, FeeTypesEnum } from '~/generated/graphql'

describe('Core > format', () => {
  describe('formatCreditNotesItems()', () => {
    it('should not format a simple items without group and with only one subscription', () => {
      const formattedItems = formatCreditNotesItems([
        {
          amountCents: '19',
          amountCurrency: CurrencyEnum.Eur,
          fee: {
            id: 'd7001ae3-1426-4cbe-9ce5-8b619d701e74',
            amountCents: '39',
            amountCurrency: CurrencyEnum.Eur,
            eventsCount: null,
            units: 1,
            feeType: FeeTypesEnum.Subscription,
            charge: null,
            subscription: {
              id: '242ccf63-d347-4148-8a94-eea2f353d657',
              name: null,
              // @ts-expect-error we're setting only the required fields for the test
              plan: {
                id: 'ffb6a9ba-97a2-4681-b875-49cf7f1ce6ac',
                name: 'Standard Plan',
              },
            },
            group: null,
          },
        },
      ])

      expect(formattedItems).toStrictEqual([
        [
          [
            {
              amountCents: '19',
              amountCurrency: 'EUR',
              fee: {
                id: 'd7001ae3-1426-4cbe-9ce5-8b619d701e74',
                amountCents: '39',
                amountCurrency: 'EUR',
                eventsCount: null,
                units: 1,
                feeType: 'subscription',
                charge: null,
                subscription: {
                  id: '242ccf63-d347-4148-8a94-eea2f353d657',
                  name: null,
                  plan: {
                    id: 'ffb6a9ba-97a2-4681-b875-49cf7f1ce6ac',
                    name: 'Standard Plan',
                  },
                },
                group: null,
              },
            },
          ],
        ],
      ])
    })

    it('should format items without group and with two subscription in two arrays', () => {
      const formattedItems = formatCreditNotesItems([
        {
          amountCents: '19',
          amountCurrency: CurrencyEnum.Eur,
          fee: {
            id: 'd7001ae3-1426-4cbe-9ce5-8b619d701e74',
            amountCents: '39',
            amountCurrency: CurrencyEnum.Eur,
            eventsCount: null,
            units: 1,
            feeType: FeeTypesEnum.Subscription,
            charge: null,
            subscription: {
              id: '242ccf63-d347-4148-8a94-eea2f353d657',
              name: null,
              // @ts-expect-error we're setting only the required fields for the test
              plan: {
                id: 'ffb6a9ba-97a2-4681-b875-49cf7f1ce6ac',
                name: 'Standard Plan',
              },
            },
            group: null,
          },
        },
        {
          amountCents: '20',
          amountCurrency: CurrencyEnum.Eur,
          fee: {
            id: 'd7001ae3-1426-4cbe-9ce5-8b619d701e75',
            amountCents: '39',
            amountCurrency: CurrencyEnum.Eur,
            eventsCount: null,
            units: 1,
            feeType: FeeTypesEnum.Subscription,
            charge: null,
            subscription: {
              id: '242ccf63-d347-4148-8a94-eea2f353d658',
              name: null,
              // @ts-expect-error we're setting only the required fields for the test
              plan: {
                id: 'ffb6a9ba-97a2-4681-b875-49cf7f1ce6ad',
                name: 'Other Plan',
              },
            },
            group: null,
          },
        },
      ])

      expect(formattedItems).toStrictEqual([
        [
          [
            {
              amountCents: '19',
              amountCurrency: 'EUR',
              fee: {
                id: 'd7001ae3-1426-4cbe-9ce5-8b619d701e74',
                amountCents: '39',
                amountCurrency: 'EUR',
                eventsCount: null,
                units: 1,
                feeType: 'subscription',
                charge: null,
                subscription: {
                  id: '242ccf63-d347-4148-8a94-eea2f353d657',
                  name: null,
                  plan: {
                    id: 'ffb6a9ba-97a2-4681-b875-49cf7f1ce6ac',
                    name: 'Standard Plan',
                  },
                },
                group: null,
              },
            },
          ],
        ],
        [
          [
            {
              amountCents: '20',
              amountCurrency: 'EUR',
              fee: {
                id: 'd7001ae3-1426-4cbe-9ce5-8b619d701e75',
                amountCents: '39',
                amountCurrency: 'EUR',
                eventsCount: null,
                units: 1,
                feeType: 'subscription',
                charge: null,
                subscription: {
                  id: '242ccf63-d347-4148-8a94-eea2f353d658',
                  name: null,
                  plan: {
                    id: 'ffb6a9ba-97a2-4681-b875-49cf7f1ce6ad',
                    name: 'Other Plan',
                  },
                },
                group: null,
              },
            },
          ],
        ],
      ])
    })

    it('should format items without group and with the same subscription in the same array', () => {
      const formattedItems = formatCreditNotesItems([
        {
          amountCents: '19',
          amountCurrency: CurrencyEnum.Eur,
          fee: {
            id: 'd7001ae3-1426-4cbe-9ce5-8b619d701e74',
            amountCents: '39',
            amountCurrency: CurrencyEnum.Eur,
            eventsCount: null,
            units: 1,
            feeType: FeeTypesEnum.Subscription,
            charge: null,
            subscription: {
              id: '242ccf63-d347-4148-8a94-eea2f353d657',
              name: null,
              // @ts-expect-error we're setting only the required fields for the test
              plan: {
                id: 'ffb6a9ba-97a2-4681-b875-49cf7f1ce6ac',
                name: 'Standard Plan',
              },
            },
            group: null,
          },
        },
        {
          amountCents: '20',
          amountCurrency: CurrencyEnum.Eur,
          fee: {
            id: 'd7001ae3-1426-4cbe-9ce5-8b619d701e75',
            amountCents: '39',
            amountCurrency: CurrencyEnum.Eur,
            eventsCount: null,
            units: 1,
            feeType: FeeTypesEnum.Subscription,
            charge: null,
            subscription: {
              id: '242ccf63-d347-4148-8a94-eea2f353d657',
              name: null,
              // @ts-expect-error we're setting only the required fields for the test
              plan: {
                id: 'ffb6a9ba-97a2-4681-b875-49cf7f1ce6ac',
                name: 'Other Plan',
              },
            },
            group: null,
          },
        },
      ])

      expect(formattedItems).toStrictEqual([
        [
          [
            {
              amountCents: '19',
              amountCurrency: 'EUR',
              fee: {
                id: 'd7001ae3-1426-4cbe-9ce5-8b619d701e74',
                amountCents: '39',
                amountCurrency: 'EUR',
                eventsCount: null,
                units: 1,
                feeType: 'subscription',
                charge: null,
                subscription: {
                  id: '242ccf63-d347-4148-8a94-eea2f353d657',
                  name: null,
                  plan: {
                    id: 'ffb6a9ba-97a2-4681-b875-49cf7f1ce6ac',
                    name: 'Standard Plan',
                  },
                },
                group: null,
              },
            },
            {
              amountCents: '20',
              amountCurrency: 'EUR',
              fee: {
                id: 'd7001ae3-1426-4cbe-9ce5-8b619d701e75',
                amountCents: '39',
                amountCurrency: 'EUR',
                eventsCount: null,
                units: 1,
                feeType: 'subscription',
                charge: null,
                subscription: {
                  id: '242ccf63-d347-4148-8a94-eea2f353d657',
                  name: null,
                  plan: {
                    id: 'ffb6a9ba-97a2-4681-b875-49cf7f1ce6ac',
                    name: 'Other Plan',
                  },
                },
                group: null,
              },
            },
          ],
        ],
      ])
    })

    it('should format items with groups and with the same subscription in the same array', () => {
      const formattedItems = formatCreditNotesItems([
        {
          amountCents: '19',
          amountCurrency: CurrencyEnum.Eur,
          fee: {
            id: 'd7001ae3-1426-4cbe-9ce5-8b619d701e74',
            amountCents: '39',
            amountCurrency: CurrencyEnum.Eur,
            eventsCount: null,
            units: 1,
            feeType: FeeTypesEnum.Subscription,
            charge: null,
            subscription: {
              id: '242ccf63-d347-4148-8a94-eea2f353d657',
              name: null,
              // @ts-expect-error we're setting only the required fields for the test
              plan: {
                id: 'ffb6a9ba-97a2-4681-b875-49cf7f1ce6ac',
                name: 'Standard Plan',
              },
            },
            group: {
              id: '1234',
              value: 'First group',
            },
          },
        },
        {
          amountCents: '20',
          amountCurrency: CurrencyEnum.Eur,
          fee: {
            id: 'd7001ae3-1426-4cbe-9ce5-8b619d701e75',
            amountCents: '39',
            amountCurrency: CurrencyEnum.Eur,
            eventsCount: null,
            units: 1,
            feeType: FeeTypesEnum.Subscription,
            charge: null,
            subscription: {
              id: '242ccf63-d347-4148-8a94-eea2f353d657',
              name: null,
              // @ts-expect-error we're setting only the required fields for the test
              plan: {
                id: 'ffb6a9ba-97a2-4681-b875-49cf7f1ce6ac',
                name: 'Other Plan',
              },
            },
            group: {
              id: '1234',
              value: 'First group',
            },
          },
        },
      ])

      expect(formattedItems).toStrictEqual([
        [
          [
            {
              amountCents: '19',
              amountCurrency: 'EUR',
              fee: {
                id: 'd7001ae3-1426-4cbe-9ce5-8b619d701e74',
                amountCents: '39',
                amountCurrency: 'EUR',
                eventsCount: null,
                units: 1,
                feeType: 'subscription',
                charge: null,
                subscription: {
                  id: '242ccf63-d347-4148-8a94-eea2f353d657',
                  name: null,
                  plan: {
                    id: 'ffb6a9ba-97a2-4681-b875-49cf7f1ce6ac',
                    name: 'Standard Plan',
                  },
                },
                group: {
                  id: '1234',
                  value: 'First group',
                },
              },
            },
            {
              amountCents: '20',
              amountCurrency: 'EUR',
              fee: {
                id: 'd7001ae3-1426-4cbe-9ce5-8b619d701e75',
                amountCents: '39',
                amountCurrency: 'EUR',
                eventsCount: null,
                units: 1,
                feeType: 'subscription',
                charge: null,
                subscription: {
                  id: '242ccf63-d347-4148-8a94-eea2f353d657',
                  name: null,
                  plan: {
                    id: 'ffb6a9ba-97a2-4681-b875-49cf7f1ce6ac',
                    name: 'Other Plan',
                  },
                },
                group: {
                  id: '1234',
                  value: 'First group',
                },
              },
            },
          ],
        ],
      ])
    })

    it('should format items without groups and with different charge id in separated arrays', () => {
      const formattedItems = formatCreditNotesItems([
        {
          amountCents: '19',
          amountCurrency: CurrencyEnum.Eur,
          fee: {
            id: 'd7001ae3-1426-4cbe-9ce5-8b619d701e74',
            amountCents: '39',
            amountCurrency: CurrencyEnum.Eur,
            eventsCount: null,
            units: 1,
            feeType: FeeTypesEnum.Subscription,
            // @ts-expect-error we're setting only the required fields for the test
            charge: {
              id: '1234',
            },
            subscription: {
              id: '242ccf63-d347-4148-8a94-eea2f353d657',
              name: null,
              // @ts-expect-error we're setting only the required fields for the test
              plan: {
                id: 'ffb6a9ba-97a2-4681-b875-49cf7f1ce6ac',
                name: 'Standard Plan',
              },
            },
            group: null,
          },
        },
        {
          amountCents: '20',
          amountCurrency: CurrencyEnum.Eur,
          fee: {
            id: 'd7001ae3-1426-4cbe-9ce5-8b619d701e75',
            amountCents: '39',
            amountCurrency: CurrencyEnum.Eur,
            eventsCount: null,
            units: 1,
            feeType: FeeTypesEnum.Subscription,
            // @ts-expect-error we're setting only the required fields for the test
            charge: { id: '5678' },
            subscription: {
              id: '242ccf63-d347-4148-8a94-eea2f353d657',
              name: null,
              // @ts-expect-error we're setting only the required fields for the test
              plan: {
                id: 'ffb6a9ba-97a2-4681-b875-49cf7f1ce6ac',
                name: 'Other Plan',
              },
            },
            group: null,
          },
        },
      ])

      expect(formattedItems).toStrictEqual([
        [
          [
            {
              amountCents: '19',
              amountCurrency: 'EUR',
              fee: {
                id: 'd7001ae3-1426-4cbe-9ce5-8b619d701e74',
                amountCents: '39',
                amountCurrency: 'EUR',
                eventsCount: null,
                units: 1,
                feeType: 'subscription',
                charge: { id: '1234' },
                subscription: {
                  id: '242ccf63-d347-4148-8a94-eea2f353d657',
                  name: null,
                  plan: {
                    id: 'ffb6a9ba-97a2-4681-b875-49cf7f1ce6ac',
                    name: 'Standard Plan',
                  },
                },
                group: null,
              },
            },
          ],
          [
            {
              amountCents: '20',
              amountCurrency: 'EUR',
              fee: {
                id: 'd7001ae3-1426-4cbe-9ce5-8b619d701e75',
                amountCents: '39',
                amountCurrency: 'EUR',
                eventsCount: null,
                units: 1,
                feeType: 'subscription',
                charge: { id: '5678' },
                subscription: {
                  id: '242ccf63-d347-4148-8a94-eea2f353d657',
                  name: null,
                  plan: {
                    id: 'ffb6a9ba-97a2-4681-b875-49cf7f1ce6ac',
                    name: 'Other Plan',
                  },
                },
                group: null,
              },
            },
          ],
        ],
      ])
    })
  })
})
