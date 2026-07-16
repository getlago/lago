import { gql } from '@apollo/client'
import type { PopperProps as MuiPopperProps } from '@mui/material/Popper'
import { PickersCalendarHeader, PickersDay } from '@mui/x-date-pickers'
import { AdapterLuxon } from '@mui/x-date-pickers/AdapterLuxon'
import { DesktopDatePicker as MuiDatePicker } from '@mui/x-date-pickers/DesktopDatePicker'
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider'
import { Icon } from 'lago-design-system'
import { DateTime, Settings } from 'luxon'
import { ReactNode, useCallback, useEffect, useState } from 'react'

import { ConditionalWrapper } from '~/components/ConditionalWrapper'
import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { TextInputProps } from '~/components/form'
import { getTimezoneConfig } from '~/core/timezone'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { theme } from '~/styles'
import { tw } from '~/styles/utils'

gql`
  fragment OrganizationForDatePicker on CurrentOrganization {
    id
    timezone
  }
`

enum DATE_PICKER_ERROR_ENUM {
  invalid = 'invalid',
}
export interface DatePickerProps extends Omit<
  TextInputProps,
  'label' | 'value' | 'onChange' | 'beforeChangeFormatter' | 'password' | 'onError'
> {
  className?: string
  value?: string | DateTime | null
  placeholder?: string
  error?: string
  label?: string | ReactNode
  helperText?: string
  defaultZone?: string // Overrides the default timezone of the date picker
  disabled?: boolean
  disableFuture?: boolean
  disablePast?: boolean
  minDate?: DateTime
  showErrorInTooltip?: boolean
  placement?: MuiPopperProps['placement']
  onError?: (err: keyof typeof DATE_PICKER_ERROR_ENUM | undefined) => void
  onChange: (value?: string | null) => void
}

export const DatePicker = ({
  className,
  name,
  value,
  error,
  label,
  description,
  defaultZone,
  disableFuture,
  disablePast,
  minDate,
  placeholder,
  disabled = false,
  showErrorInTooltip = false,
  placement = 'bottom-end',
  onError,
  onChange,
  helperText,
}: DatePickerProps) => {
  const { translate } = useInternationalization()
  const { organization } = useOrganizationInfos()

  /**
   * Date will be passed to the parent as ISO
   * So we need to make sure to re-transform to DateTime for the component to read it
   */
  const getValueFormatted = useCallback(() => {
    if (!value) return null

    return typeof value === 'string' ? DateTime.fromISO(value) : value
  }, [value])

  const [localDate, setLocalDate] = useState<DateTime | null>(getValueFormatted())

  const isInvalid = !!localDate && !localDate.isValid

  const getHelperText = useCallback(() => {
    if (!!error || isInvalid) {
      if (!showErrorInTooltip) {
        return error || translate('text_62cd78ea9bff25e3391b2459')
      }

      return ''
    }
    return helperText
  }, [error, helperText, isInvalid, showErrorInTooltip, translate])

  useEffect(() => {
    if (defaultZone) Settings.defaultZone = defaultZone

    return () => {
      // Reset timezone to default
      if (defaultZone) Settings.defaultZone = getTimezoneConfig(organization?.timezone).name
    }

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    setLocalDate(getValueFormatted())
  }, [getValueFormatted])

  return (
    <LocalizationProvider dateAdapter={AdapterLuxon}>
      <div className={tw('relative flex flex-col gap-1', className)}>
        {!!label && (
          <>
            {typeof label === 'string' ? (
              <Typography variant="captionHl" color="textSecondary">
                {label}
              </Typography>
            ) : (
              label
            )}
          </>
        )}

        {!!description && (
          <Typography className="mb-3" variant="caption">
            {description}
          </Typography>
        )}

        <ConditionalWrapper
          condition={showErrorInTooltip && (!!error || isInvalid)}
          validWrapper={(children) => (
            <Tooltip
              title={error || translate('text_62cd78ea9bff25e3391b2459')}
              placement="top-end"
            >
              {children}
            </Tooltip>
          )}
          invalidWrapper={(children) => <>{children}</>}
        >
          <MuiDatePicker
            name={name}
            format="MM/dd/yyyy"
            disableFuture={disableFuture}
            disabled={disabled}
            disablePast={disablePast}
            minDate={minDate}
            value={localDate}
            onChange={(date) => {
              setLocalDate(!date ? date : (date as unknown as DateTime).toUTC())

              // To avoid breaking dates in the parent, we do not pass it unless it's valid
              const formattedDate = !date
                ? undefined
                : (date as unknown as DateTime)?.toUTC().toISO()

              if ((date as unknown as DateTime)?.isValid || !date) {
                onError && onError(undefined)
                onChange(formattedDate)
              } else {
                onError && onError(DATE_PICKER_ERROR_ENUM.invalid)
              }
            }}
            slots={{
              calendarHeader: (calendarHeaderProps) => (
                <PickersCalendarHeader
                  {...calendarHeaderProps}
                  className="custom-date-picker-header"
                />
              ),
              day: (dayProps) => (
                <PickersDay
                  {...dayProps}
                  disableRipple
                  disableTouchRipple
                  className="custom-date-picker-day"
                />
              ),
              switchViewButton: () => (
                <Button
                  className="m-1"
                  variant="quaternary"
                  disabled={disabled}
                  icon="chevron-down"
                  size="small"
                />
              ),
              leftArrowIcon: () => <Icon name="chevron-left" />,
              rightArrowIcon: () => <Icon name="chevron-right" />,
              clearButton: () => (
                <Button
                  className="button-clear-date"
                  disabled={disabled}
                  icon="close-circle-filled"
                  size="small"
                  variant="quaternary"
                />
              ),
              openPickerButton: (pickerProps) => (
                <Tooltip
                  className="open-picker-tooltip"
                  disableHoverListener={disabled}
                  placement="top-end"
                  title={translate('text_62cd78ea9bff25e3391b2437')}
                >
                  <Button
                    disabled={disabled}
                    icon="calendar"
                    onClick={pickerProps.onClick}
                    size="small"
                    variant="quaternary"
                  />
                </Tooltip>
              ),
            }}
            slotProps={{
              popper: {
                placement,
                modifiers: [
                  {
                    name: 'flip',
                    enabled: placement === 'auto',
                  },
                  {
                    name: 'offset',
                    enabled: true,
                    options: {
                      offset: ({ reference }: { reference: { width: number } }) => {
                        // Re-calculate picker position if placed on the left.
                        // Removes the input width and twice the picker icon "box" (24*2)
                        if (placement.includes('left')) {
                          return [0, -(reference.width - 48)]
                        }

                        return [0, 8]
                      },
                    },
                  },
                ],
              },
              textField: {
                placeholder: placeholder || translate('text_62cd78ea9bff25e3391b243d'),
                error: !!error || isInvalid,
                helperText: getHelperText(),
              },
              openPickerButton: {
                style: {
                  padding: 0,
                  marginRight: 0,
                  height: 'fit-content',
                },
              },
              desktopPaper: {
                style: {
                  border: `1px solid ${theme.palette.grey[200]}`,
                  boxShadow: '0px 6px 8px 0px #19212E1F',
                  width: '352px',
                  padding: `${theme.spacing(6)} 0`,
                  boxSizing: 'border-box',
                },
              },
            }}
            sx={{
              '& .MuiFormHelperText-contained': {
                margin: '4px 0 0',
              },
              '& .MuiFormHelperText-root.Mui-error': {
                color: theme.palette.error.main,
              },
              '& .MuiFormHelperText-root': {
                color: theme.palette.grey[600],
              },
            }}
          />
        </ConditionalWrapper>
      </div>
    </LocalizationProvider>
  )
}
