import ace from 'ace-builds/src-noconflict/ace'
import 'ace-builds/src-noconflict/ext-language_tools'
import 'ace-builds/src-noconflict/mode-json'
import 'ace-builds/src-noconflict/theme-github'
// https://github.com/securingsincity/react-ace/issues/725#issuecomment-1086221818
import jsonWorkerUrl from 'ace-builds/src-noconflict/worker-json?url'
import { Icon } from 'lago-design-system'
import { ReactNode, useEffect, useRef, useState } from 'react'
import AceEditor from 'react-ace'

import { Chip } from '~/components/designSystem/Chip'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { tw } from '~/styles/utils'

import './jsonEditor.css'

ace.config.setModuleUrl('ace/mode/json_worker', jsonWorkerUrl)

enum JSON_EDITOR_ERROR_ENUM {
  invalid = 'invalid',
  invalidCustomValidate = 'invalidCustomValidate',
}
export interface JsonEditorProps {
  label: string
  description?: string
  name?: string
  placeholder?: string
  value?: string | Record<string, unknown>
  infoText?: string
  error?: string
  helperText?: string | ReactNode
  customInvalidError?: string
  disabled?: boolean
  readOnly?: boolean
  readOnlyWithoutStyles?: boolean
  height?: string
  hideLabel?: boolean
  editorMode?: 'text' | 'json'
  showHelperOnError?: boolean
  validate?: (value: string) => void
  onBlur?: (props: unknown) => void
  onChange?: (value: string) => void
  onError?: (err: keyof typeof JSON_EDITOR_ERROR_ENUM) => void
  onExpand?: (deleteOverlay: () => void) => void
}

export const JsonEditor = ({
  name,
  value,
  placeholder,
  label,
  description,
  infoText,
  helperText,
  error,
  customInvalidError,
  disabled,
  readOnly,
  readOnlyWithoutStyles,
  height,
  hideLabel,
  editorMode = 'json',
  showHelperOnError,
  validate,
  onChange,
  onError,
  onBlur,
  onExpand,
}: JsonEditorProps) => {
  const { translate } = useInternationalization()
  const editorRef = useRef<AceEditor | null>(null)
  const [jsonQuery, setJsonQuery] = useState<string | undefined>()
  const [showOverlay, setShowOverlay] = useState(true)
  const [isHover, setHover] = useState(false)

  useEffect(() => {
    if (typeof value === 'object') {
      try {
        setJsonQuery(JSON.stringify(value, null, 2))
      } catch {
        // Nothing is supposed to happen here
      }
    } else {
      setJsonQuery(value)
    }
  }, [value])

  return (
    <div className="grid w-full grid-rows-[auto-1fr-auto]">
      {!hideLabel && (
        <div>
          <div className="mb-1 flex items-center">
            <Typography variant="captionHl" color="textSecondary">
              {label}
            </Typography>
            {!!infoText && (
              <Tooltip
                className="ml-1 flex h-5 items-end"
                placement="bottom-start"
                title={infoText}
              >
                <Icon name="info-circle" />
              </Tooltip>
            )}
          </div>
          {description && (
            <div className="mb-4">
              <Typography variant="caption">{description}</Typography>
            </div>
          )}
        </div>
      )}

      <div
        style={{ height: height ?? undefined }}
        className={tw(
          'relative h-full overflow-hidden',
          !readOnly && 'rounded-xl border border-grey-500',
          !!error && 'border-red-600',
          (!!helperText || !!error) && 'mb-1',
        )}
        aria-label={name}
        onMouseEnter={() => {
          if (!isHover) {
            setHover(true)
          }
        }}
        onMouseLeave={() => {
          if (isHover) {
            setHover(false)
          }
        }}
      >
        {onExpand && (
          <div
            className={tw(
              'absolute inset-0 z-10 rounded-xl bg-gradient-to-t from-white from-20% transition-opacity',
              showOverlay ? 'opacity-100' : '-z-10 opacity-0',
            )}
          >
            <button
              type="button"
              className={tw(
                'flex size-full cursor-pointer items-center justify-center rounded-none border-none bg-none transition-opacity',
                isHover ? 'opacity-100' : 'opacity-0',
              )}
              onClick={() => onExpand(() => setShowOverlay(false))}
            >
              <Chip icon="plus" label={translate('text_663dea5702b60301d8d0650a')} />
            </button>
          </div>
        )}

        <div className="absolute left-0 top-0 h-full w-[42px] bg-grey-100" />
        <AceEditor
          ref={editorRef}
          className={tw(
            'ace-editor',
            disabled && 'json-editor--disabled',
            readOnly && 'json-editor--readonly',
            readOnlyWithoutStyles && 'json-editor--readonlywithoutstyles',
          )}
          value={jsonQuery}
          onLoad={(editor) => {
            editor.renderer.setPadding(4)
            editor.renderer.setScrollMargin(10, 10, 0, 0)
          }}
          mode={editorMode}
          onChange={(code) => {
            setJsonQuery(code)
            onChange && onChange(code)
          }}
          onBlur={(event) => {
            if (!jsonQuery) return true

            if (validate) {
              try {
                validate(jsonQuery)
              } catch {
                onError && onError(JSON_EDITOR_ERROR_ENUM.invalidCustomValidate)
              }
            } else if (editorMode === 'json') {
              try {
                JSON.parse(jsonQuery)
              } catch {
                onError && onError(JSON_EDITOR_ERROR_ENUM.invalid)
              }
            }
            setShowOverlay(true)
            onBlur && onBlur(event)
          }}
          fontSize={14}
          width="100%"
          height="100%"
          placeholder={placeholder}
          setOptions={{
            useWorker: true,
            enableBasicAutocompletion: false,
            enableLiveAutocompletion: false,
            showLineNumbers: true,
            tabSize: 2,
            showPrintMargin: false,
            readOnly: readOnly || readOnlyWithoutStyles || disabled,
          }}
        />
      </div>

      {helperText && !error && (
        <Typography variant="caption" color="textPrimary">
          {helperText}
        </Typography>
      )}

      {error && (
        <Typography variant="caption" color="danger600">
          {customInvalidError}

          {!customInvalidError &&
            error === JSON_EDITOR_ERROR_ENUM.invalid &&
            translate('text_6638a3538de76801ac2f451b')}

          {!customInvalidError &&
            error === JSON_EDITOR_ERROR_ENUM.invalidCustomValidate &&
            translate('text_1729864971171gfdioq71rvt')}
        </Typography>
      )}

      {helperText && showHelperOnError && error && (
        <Typography variant="caption" color="textPrimary">
          {helperText}
        </Typography>
      )}
    </div>
  )
}
