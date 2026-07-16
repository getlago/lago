import { TRANSLATIONS_MAP_CUSTOMER_TYPE } from '~/components/customers/utils'
import { Typography } from '~/components/designSystem/Typography'
import { InfoRow } from '~/components/InfoRow'
import { formatAddress } from '~/core/formats/formatAddress'
import { getTimezoneConfig } from '~/core/timezone'
import { CustomerMainInfosFragment, TimezoneEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

const CustomerInfoRows = ({ customer }: { customer: CustomerMainInfosFragment }) => {
  const { translate } = useInternationalization()

  const { addressLine1, addressLine2, state, country, city, zipcode, shippingAddress, metadata } =
    customer

  const formattedAddress = formatAddress({
    addressLine1,
    addressLine2,
    city,
    country,
    state,
    zipcode,
  })

  const formattedShippingAddress = formatAddress({
    addressLine1: shippingAddress?.addressLine1,
    addressLine2: shippingAddress?.addressLine2,
    city: shippingAddress?.city,
    country: shippingAddress?.country,
    state: shippingAddress?.state,
    zipcode: shippingAddress?.zipcode,
  })

  const customerFields = [
    {
      key: 'billingEntity',
      caption: translate('text_1743611497157teaa1zu8l24'),
      value: (customerData: CustomerMainInfosFragment) =>
        customerData?.billingEntity?.name || customerData?.billingEntity?.code,
    },
    {
      key: 'customerType',
      caption: translate('text_1726128938631ioz4orixel3'),
      value: (customerData: CustomerMainInfosFragment) =>
        customerData?.customerType
          ? translate(TRANSLATIONS_MAP_CUSTOMER_TYPE[customerData.customerType])
          : '',
    },
    {
      key: 'name',
      caption: translate('text_626162c62f790600f850b76a'),
      value: (customerData: CustomerMainInfosFragment) => customerData?.name,
    },
    {
      key: 'fullname',
      caption: translate('text_17261289386311s35rvzyxbz'),
      value: (customerData: CustomerMainInfosFragment) =>
        `${customerData?.firstname || ''} ${customerData?.lastname || ''}`.trim(),
    },
    {
      key: 'externalId',
      caption: translate('text_6250304370f0f700a8fdc283'),
      value: (customerData: CustomerMainInfosFragment) => customerData?.externalId,
    },
    {
      key: 'timezone',
      caption: translate('text_6390a767b79591bc70ba39f7'),
      value: (customerData: CustomerMainInfosFragment) =>
        customerData?.timezone
          ? translate('text_638f743fa9a2a9545ee6409a', {
              zone: translate(customerData.timezone || TimezoneEnum.TzUtc),
              offset: getTimezoneConfig(customerData.timezone).offset,
            })
          : '',
    },
    {
      key: 'externalSalesforceId',
      caption: translate('text_651fd42936a03200c126c683'),
      value: (customerData: CustomerMainInfosFragment) => customerData?.externalSalesforceId,
    },
    {
      key: 'currency',
      caption: translate('text_632b4acf0c41206cbcb8c324'),
      value: (customerData: CustomerMainInfosFragment) => customerData?.currency,
    },
    {
      key: 'legalName',
      caption: translate('text_626c0c301a16a600ea061471'),
      value: (customerData: CustomerMainInfosFragment) => customerData?.legalName,
    },
    {
      key: 'legalNumber',
      caption: translate('text_626c0c301a16a600ea061475'),
      value: (customerData: CustomerMainInfosFragment) => customerData?.legalNumber,
    },
    {
      key: 'taxIdentificationNumber',
      caption: translate('text_648053ee819b60364c675d05'),
      value: (customerData: CustomerMainInfosFragment) => customerData?.taxIdentificationNumber,
    },
    {
      key: 'email',
      caption: translate('text_626c0c301a16a600ea061479'),
      value: (customerData: CustomerMainInfosFragment) =>
        customerData?.email ? customerData?.email.split(',').join(', ') : '',
    },
    {
      key: 'url',
      caption: translate('text_641b164cff8497006bcbd2b3'),
      value: (customerData: CustomerMainInfosFragment) => customerData?.url,
    },
    {
      key: 'phone',
      caption: translate('text_626c0c301a16a600ea06147d'),
      value: (customerData: CustomerMainInfosFragment) => customerData?.phone,
    },
    {
      key: 'formattedAddress',
      caption: translate('text_626c0c301a16a600ea06148d'),
      value: () => formattedAddress,
    },
    {
      key: 'formattedShippingAddress',
      caption: translate('text_667d708c1359b49f5a5a822a'),
      value: () => formattedShippingAddress,
    },
    ...(Array.isArray(metadata) && metadata.length > 0
      ? metadata.map((meta) => ({
          key: `metadata-${meta.id}`,
          caption: meta.key,
          value: () => meta.value,
        }))
      : []),
  ]

  return customerFields.map(({ key, caption, value }, i) => {
    const fieldValue = value(customer)

    if (!fieldValue) {
      return null
    }

    const fieldValues = Array.isArray(fieldValue) ? fieldValue : [fieldValue]

    return fieldValues.map((item, index) => (
      <InfoRow key={`${key}-${i}-${index}`}>
        <Typography variant="caption">{caption}</Typography>
        <div className="flex flex-col">
          <Typography color="textSecondary" forceBreak>
            {item}
          </Typography>
        </div>
      </InfoRow>
    ))
  })
}

export { CustomerInfoRows }
