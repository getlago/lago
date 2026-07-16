export const feeMockFormatedForEstimate = [
  { amountCents: 1000000, feeId: 'fee1' },
  { amountCents: 1900000, feeId: 'fee2' },
  { amountCents: 50000, feeId: 'fee4' },
  { amountCents: 50000, feeId: 'fee5' },
]

export const feesMock = {
  subscriptionId1: {
    subscriptionName: 'Subscription 1',
    fees: [
      {
        id: 'fee1',
        name: 'Fee 1',
        checked: true,
        maxAmount: 10000,
        value: 10000,
        appliedTaxes: [
          {
            id: 'tax1',
            taxName: 'Tax 1',
            taxRate: 10,
          },
        ],
      },
      {
        id: 'fee2',
        name: 'Fee 2',
        checked: true,
        maxAmount: 20000,
        value: 19000,
        appliedTaxes: [
          {
            id: 'tax2',
            taxName: 'Tax 2',
            taxRate: 20,
          },
        ],
      },
      {
        id: 'fee3',
        name: 'Fee 3',
        checked: false,
        maxAmount: 10,
        value: 10,
        appliedTaxes: [],
      },
    ],
  },
  subscriptionId2: {
    subscriptionName: 'Subscription 2',
    fees: [
      {
        id: 'fee4',
        name: 'Fee 4',
        checked: true,
        maxAmount: 10000,
        value: 500,
      },
      {
        id: 'fee5',
        name: 'Fee 5',
        checked: true,
        maxAmount: 10000,
        value: 500,
        appliedTaxes: [
          {
            id: 'tax1',
            taxName: 'Tax 1',
            taxRate: 10,
          },
          {
            id: 'tax2',
            taxName: 'Tax 2',
            taxRate: 20,
          },
        ],
      },
    ],
  },
}

export const addonMockFormatedForEstimate = [
  {
    amountCents: 50000,
    feeId: 'addOnFee1',
  },
]

export const addOnFeeMock = [
  {
    id: 'addOnFee1',
    name: 'Add on fee',
    amount: 10000,
    taxRate: 30,
    checked: true,
    maxAmount: 10000,
    value: 500,
    appliedTaxes: [
      {
        id: 'tax1',
        taxName: 'Tax 1',
        taxRate: 10,
      },
      {
        id: 'tax2',
        taxName: 'Tax 2',
        taxRate: 20,
      },
    ],
  },
  {
    id: 'addOnFee2',
    name: 'Add on fee',
    amount: 20000,
    taxRate: 30,
    checked: false,
    maxAmount: 10000,
    value: 500,
    appliedTaxes: [
      {
        id: 'tax1',
        taxName: 'Tax 1',
        taxRate: 10,
      },
    ],
  },
]
