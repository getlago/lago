import { Properties, PropertiesInput } from '~/generated/graphql'

const getPropertyShape = (properties: Properties | undefined): PropertiesInput => {
  return {
    amount: properties?.amount || undefined,
    pricingGroupKeys: !!properties?.pricingGroupKeys?.length ? properties?.pricingGroupKeys : [],
    // ComboBoxField stores displayInInvoice as 'true'/'false' strings at runtime,
    // but we keep PropertiesInput (boolean) for type compatibility across consumers.
    presentationGroupKeys: (properties?.presentationGroupKeys || []).map((key) => ({
      ...key,
      options: {
        ...key.options,
        displayInInvoice: (key.options?.displayInInvoice ? 'true' : 'false') as unknown as boolean,
      },
    })),
    packageSize:
      properties?.packageSize === null || properties?.packageSize === undefined
        ? 10
        : properties?.packageSize,
    fixedAmount: properties?.fixedAmount || undefined,
    freeUnitsPerEvents: properties?.freeUnitsPerEvents || undefined,
    freeUnitsPerTotalAggregation: properties?.freeUnitsPerTotalAggregation || undefined,
    perTransactionMinAmount: properties?.perTransactionMinAmount || undefined,
    perTransactionMaxAmount: properties?.perTransactionMaxAmount || undefined,
    freeUnits: properties?.freeUnits || 0,
    graduatedRanges: properties?.graduatedRanges || undefined,
    graduatedPercentageRanges: properties?.graduatedPercentageRanges || undefined,
    volumeRanges: properties?.volumeRanges || undefined,
    rate: properties?.rate || undefined,
    customProperties: properties?.customProperties || undefined,
  }
}

export default getPropertyShape
