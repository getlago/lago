import { gql } from '@apollo/client'
import { useStore } from '@tanstack/react-form'
import { useCallback, useMemo, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Selector } from '~/components/designSystem/Selector'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { ComboBox, ComboboxItem } from '~/components/form'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import {
  MUI_INPUT_BASE_ROOT_CLASSNAME,
  SEARCH_FEATURE_PRIVILEGE_SELECT_OPTIONS_INPUT_CLASSNAME,
  SEARCH_FEATURE_SELECT_OPTIONS_INPUT_CLASSNAME,
} from '~/core/constants/form'
import { scrollToAndClickElement } from '~/core/utils/domUtils'
import {
  LagoApiError,
  useGetFeatureDetailsForFeatureEntitlementPrivilegeSectionQuery,
  useGetFeaturesListForPlanSectionLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'

import { DEFAULT_VALUES } from './constants'
import { PrivilegesTable } from './PrivilegesTable'

gql`
  fragment FeatureEntitlementPrivilegeForPlan on PlanEntitlementPrivilegeObject {
    code
    name
    value
    valueType
    config {
      selectOptions
    }
  }

  fragment FeatureObjectEntitlementPrivilegeForPlan on FeatureObject {
    id
    code
    name
    privileges {
      id
      name
      code
      valueType
      config {
        selectOptions
      }
    }
  }

  query getFeatureDetailsForFeatureEntitlementPrivilegeSection($code: String) {
    feature(code: $code) {
      ...FeatureObjectEntitlementPrivilegeForPlan
    }
  }
`

interface FeatureEntitlementDrawerContentExtraProps {
  existingFeatureCodes: string[]
}

const featureEntitlementDrawerContentDefaultProps: FeatureEntitlementDrawerContentExtraProps = {
  existingFeatureCodes: [],
}

export const FeatureEntitlementDrawerContent = withForm({
  defaultValues: DEFAULT_VALUES,
  props: featureEntitlementDrawerContentDefaultProps,
  render: function FeatureEntitlementDrawerContentRender({ form, existingFeatureCodes }) {
    const { translate } = useInternationalization()
    const [displayAddPrivilegeInput, setDisplayAddPrivilegeInput] = useState(false)

    const values = useStore(form.store, (state) => state.values)
    const isFeatureNotSelected = values.featureCode === ''

    const [getFeaturesList, { data: featuresListData, loading: isLoadingFeaturesList }] =
      useGetFeaturesListForPlanSectionLazyQuery()

    const { data: featureDetailsData, loading: featureDetailsLoading } =
      useGetFeatureDetailsForFeatureEntitlementPrivilegeSectionQuery({
        variables: { code: values.featureCode },
        skip: !values.featureCode,
        context: { silentErrorCodes: [LagoApiError.NotFound] },
      })

    const featuresListComboBoxData = useMemo(() => {
      if (!featuresListData?.features?.collection.length) return []

      return featuresListData.features.collection.map((feature) => {
        const { name, code } = feature

        return {
          value: code,
          label: `${name} (${code})`,
          labelNode: (
            <ComboboxItem>
              <Typography variant="body" color="grey700" noWrap>
                {name}
              </Typography>
              <Typography variant="caption" color="grey600" noWrap>
                {code}
              </Typography>
            </ComboboxItem>
          ),
          disabled: existingFeatureCodes.includes(code),
        }
      })
    }, [featuresListData, existingFeatureCodes])

    const privilegesListComboBoxData = useMemo(() => {
      if (!featureDetailsData?.feature.privileges?.length) return []

      return featureDetailsData.feature.privileges.map((privilege) => {
        const { id, code, name } = privilege

        return {
          value: id,
          label: `${name} (${code})`,
          labelNode: (
            <ComboboxItem>
              <Typography variant="body" color="grey700" noWrap>
                {name}
              </Typography>
              <Typography variant="caption" color="grey600" noWrap>
                {code}
              </Typography>
            </ComboboxItem>
          ),
          disabled: values.privileges?.some((p) => p.privilegeCode === code),
        }
      })
    }, [values.privileges, featureDetailsData?.feature.privileges])

    const onAddPrivilege = useCallback(
      (selectedPrivilegeId: string) => {
        if (!selectedPrivilegeId) return

        const selectedPrivilegeFullData = featureDetailsData?.feature.privileges.find(
          (privilege) => privilege.id === selectedPrivilegeId,
        )

        if (!selectedPrivilegeFullData) {
          setDisplayAddPrivilegeInput(false)
          return
        }

        form.setFieldValue('privileges', [
          ...values.privileges,
          {
            privilegeCode: selectedPrivilegeFullData.code,
            privilegeName: selectedPrivilegeFullData.name,
            valueType: selectedPrivilegeFullData.valueType,
            config: selectedPrivilegeFullData.config,
            value: '',
          },
        ])

        setDisplayAddPrivilegeInput(false)
      },
      [featureDetailsData, values.privileges, form],
    )

    const handleFormSubmit = (event: React.FormEvent) => {
      event.preventDefault()
      form.handleSubmit()
    }

    return (
      <form onSubmit={handleFormSubmit}>
        <button type="submit" hidden aria-hidden="true" />
        <CenteredPage.SectionWrapper>
          <CenteredPage.PageTitle
            title={translate('text_63e26d8308d03687188221a6')}
            description={translate('text_17538642230602p03937fj0f')}
          />

          <CenteredPage.SubsectionWrapper>
            <CenteredPage.PageSection>
              <CenteredPage.PageSectionTitle title={translate('text_1773428494589gq89ubgz99i')} />

              {!isFeatureNotSelected && (
                <Selector
                  icon="switch"
                  title={values.featureName || values.featureCode}
                  subtitle={values.featureCode}
                />
              )}
              {isFeatureNotSelected && (
                <form.AppField
                  name="featureCode"
                  listeners={{
                    onChange: ({ value }) => {
                      const selectedFeature = featuresListData?.features?.collection.find(
                        (feature) => feature.code === value,
                      )

                      if (!selectedFeature) return

                      form.setFieldValue('featureId', selectedFeature.id)
                      form.setFieldValue('featureName', selectedFeature.name || '')
                    },
                  }}
                >
                  {(field) => (
                    <field.ComboBoxField
                      disableClearable
                      containerClassName="w-full"
                      placeholder={translate('text_1753864223060h6i2e7303eb')}
                      loading={isLoadingFeaturesList}
                      data={featuresListComboBoxData}
                      className={SEARCH_FEATURE_SELECT_OPTIONS_INPUT_CLASSNAME}
                      searchQuery={getFeaturesList}
                    />
                  )}
                </form.AppField>
              )}
            </CenteredPage.PageSection>

            {!!values.featureCode && (
              <CenteredPage.PageSection>
                <CenteredPage.PageSectionTitle
                  title={translate('text_17538642230604pul58koirl')}
                  description={translate('text_1753864223060yrey0yur60j')}
                />

                {values.privileges.length > 0 && (
                  <PrivilegesTable form={form} featureCode={values.featureCode} />
                )}

                {displayAddPrivilegeInput ? (
                  <div className="flex w-full items-center gap-3">
                    <ComboBox
                      disableClearable
                      containerClassName="w-full"
                      placeholder={translate('text_1753864223060yk3svyv4dpr')}
                      loading={featureDetailsLoading}
                      data={privilegesListComboBoxData}
                      className={SEARCH_FEATURE_PRIVILEGE_SELECT_OPTIONS_INPUT_CLASSNAME}
                      onChange={onAddPrivilege}
                    />

                    <Tooltip placement="top-end" title={translate('text_63ea0f84f400488553caa786')}>
                      <Button
                        variant="quaternary"
                        icon="trash"
                        onClick={() => {
                          setDisplayAddPrivilegeInput(false)
                        }}
                      />
                    </Tooltip>
                  </div>
                ) : (
                  <Button
                    fitContent
                    align="left"
                    variant="inline"
                    startIcon="plus"
                    onClick={() => {
                      setDisplayAddPrivilegeInput(true)

                      scrollToAndClickElement({
                        selector: `.${SEARCH_FEATURE_PRIVILEGE_SELECT_OPTIONS_INPUT_CLASSNAME} .${MUI_INPUT_BASE_ROOT_CLASSNAME}`,
                      })
                    }}
                  >
                    {translate('text_1753864223060n9hxs03sa15')}
                  </Button>
                )}
              </CenteredPage.PageSection>
            )}
          </CenteredPage.SubsectionWrapper>
        </CenteredPage.SectionWrapper>
      </form>
    )
  },
})
