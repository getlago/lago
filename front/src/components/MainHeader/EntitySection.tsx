import { Icon, IconName } from 'lago-design-system'
import { FC } from 'react'

import { Avatar } from '~/components/designSystem/Avatar'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Status, StatusType } from '~/components/designSystem/Status'
import { Typography } from '~/components/designSystem/Typography'

import {
  ENTITY_SECTION_METADATA_TEST_ID,
  ENTITY_SECTION_TEST_ID,
  ENTITY_SECTION_VIEW_NAME_TEST_ID,
} from './mainHeaderTestIds'
import { MainHeaderEntityConfig } from './types'

/**
 * Entity section — renders as a fragment so the parent controls layout.
 */
export const EntitySection: FC<{ entity?: MainHeaderEntityConfig }> = ({ entity }) => {
  if (!entity) return null

  return (
    <div className="flex items-center gap-3">
      {entity.icon && (
        <Avatar
          variant={typeof entity.icon === 'string' ? 'connector' : 'connector-full'}
          size="large"
          className="!size-[52px] !min-w-[52px]"
        >
          {typeof entity.icon === 'string' ? (
            <Icon name={entity.icon as IconName} color="dark" size="large" />
          ) : (
            entity.icon
          )}
        </Avatar>
      )}
      <div data-test={ENTITY_SECTION_TEST_ID}>
        <div className="flex items-center gap-2">
          {entity.viewNameLoading ? (
            <Skeleton variant="text" className="w-50" />
          ) : (
            <>
              <Typography
                color="textSecondary"
                variant="headline"
                forceBreak
                data-test={ENTITY_SECTION_VIEW_NAME_TEST_ID}
              >
                {entity.viewName}
              </Typography>
              {entity.badges?.map((badge) => (
                <Status
                  key={`${badge.type}-${badge.label}`}
                  type={badge.type as StatusType}
                  label={badge.label}
                  labelVariables={badge.labelVariables}
                  endIcon={badge.endIcon}
                />
              ))}
            </>
          )}
        </div>
        {entity.metadataLoading && <Skeleton variant="text" className="w-24" />}
        {!entity.metadataLoading &&
          entity.metadata &&
          (typeof entity.metadata === 'string' ? (
            <Typography data-test={ENTITY_SECTION_METADATA_TEST_ID}>{entity.metadata}</Typography>
          ) : (
            <div data-test={ENTITY_SECTION_METADATA_TEST_ID}>{entity.metadata}</div>
          ))}
      </div>
    </div>
  )
}
