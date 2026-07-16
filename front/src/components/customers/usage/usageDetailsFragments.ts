import { gql } from '@apollo/client'

gql`
  fragment CustomerUsageForUsageDetails on CustomerUsage {
    fromDatetime
    toDatetime
    chargesUsage {
      id
      pricingUnitAmountCents
      charge {
        id
        invoiceDisplayName
        appliedPricingUnit {
          id
          pricingUnit {
            id
            shortName
          }
        }
      }
      billableMetric {
        code
        name
      }
      filters {
        id
        amountCents
        units
        values
        invoiceDisplayName
        pricingUnitAmountCents
        presentationBreakdowns {
          presentationBy
          units
        }
      }
      groupedUsage {
        id
        amountCents
        groupedBy
        eventsCount
        units
        pricingUnitAmountCents
        filters {
          id
          amountCents
          units
          values
          invoiceDisplayName
          pricingUnitAmountCents
          presentationBreakdowns {
            presentationBy
            units
          }
        }
        presentationBreakdowns {
          presentationBy
          units
        }
      }
      presentationBreakdowns {
        presentationBy
        units
      }
    }
  }

  fragment CustomerProjectedUsageForUsageDetails on CustomerProjectedUsage {
    fromDatetime
    toDatetime
    chargesUsage {
      id
      pricingUnitAmountCents
      pricingUnitProjectedAmountCents
      charge {
        id
        invoiceDisplayName
        appliedPricingUnit {
          id
          pricingUnit {
            id
            shortName
          }
        }
      }
      billableMetric {
        code
        name
      }
      filters {
        id
        amountCents
        units
        values
        invoiceDisplayName
        pricingUnitAmountCents
        projectedAmountCents
        pricingUnitProjectedAmountCents
        projectedUnits
        presentationBreakdowns {
          presentationBy
          units
        }
        projectedPresentationBreakdowns {
          presentationBy
          units
        }
      }
      groupedUsage {
        id
        amountCents
        groupedBy
        eventsCount
        units
        pricingUnitAmountCents
        projectedAmountCents
        pricingUnitProjectedAmountCents
        projectedUnits
        filters {
          id
          amountCents
          units
          values
          invoiceDisplayName
          pricingUnitAmountCents
          projectedAmountCents
          pricingUnitProjectedAmountCents
          projectedUnits
          presentationBreakdowns {
            presentationBy
            units
          }
          projectedPresentationBreakdowns {
            presentationBy
            units
          }
        }
        presentationBreakdowns {
          presentationBy
          units
        }
        projectedPresentationBreakdowns {
          presentationBy
          units
        }
      }
      presentationBreakdowns {
        presentationBy
        units
      }
      projectedPresentationBreakdowns {
        presentationBy
        units
      }
    }
  }
`
