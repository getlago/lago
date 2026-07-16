import { FC } from 'react'

import { render } from '~/test-utils'

import { MainHeaderConfigure } from '../MainHeaderConfigure'
import { MainHeaderProvider, useMainHeaderReader } from '../MainHeaderContext'
import { MainHeaderConfig } from '../types'

const mockConfig: MainHeaderConfig = {
  breadcrumb: [{ label: 'Page', path: '/page' }],
}

describe('MainHeaderConfigure', () => {
  describe('GIVEN the component is rendered', () => {
    describe('WHEN mounted with config props', () => {
      it('THEN should render nothing (returns null)', () => {
        const { container } = render(
          <MainHeaderProvider>
            <MainHeaderConfigure {...mockConfig} />
          </MainHeaderProvider>,
        )

        expect(container.innerHTML).toBe('')
      })
    })

    describe('WHEN mounted with a config', () => {
      it('THEN should push config to context', () => {
        const ReadConfigSpy: FC<{ onConfig: (config: MainHeaderConfig | null) => void }> = ({
          onConfig,
        }) => {
          const { config } = useMainHeaderReader()

          onConfig(config)

          return null
        }

        let capturedConfig: MainHeaderConfig | null = null

        render(
          <MainHeaderProvider>
            <MainHeaderConfigure {...mockConfig} />
            <ReadConfigSpy onConfig={(c) => (capturedConfig = c)} />
          </MainHeaderProvider>,
        )

        expect(capturedConfig).toEqual(mockConfig)
      })
    })

    describe('WHEN unmounted', () => {
      it('THEN should reset config to null', () => {
        const ReadConfigSpy: FC<{ onConfig: (config: MainHeaderConfig | null) => void }> = ({
          onConfig,
        }) => {
          const { config } = useMainHeaderReader()

          onConfig(config)

          return null
        }

        let capturedConfig: MainHeaderConfig | null = null

        const { rerender } = render(
          <MainHeaderProvider>
            <MainHeaderConfigure {...mockConfig} />
            <ReadConfigSpy onConfig={(c) => (capturedConfig = c)} />
          </MainHeaderProvider>,
        )

        expect(capturedConfig).toEqual(mockConfig)

        rerender(
          <MainHeaderProvider>
            <ReadConfigSpy onConfig={(c) => (capturedConfig = c)} />
          </MainHeaderProvider>,
        )

        expect(capturedConfig).toBeNull()
      })
    })
  })

  describe('GIVEN only tab content changes (content is stripped from the snapshot)', () => {
    const ReadTabContentSpy: FC<{ onContent: (content: unknown) => void }> = ({ onContent }) => {
      const { config } = useMainHeaderReader()

      onContent(config?.tabs?.[0]?.content)

      return null
    }

    const makeConfig = (
      label: string,
      snapshotKey?: string | number | boolean,
    ): MainHeaderConfig => ({
      breadcrumb: [{ label: 'Page', path: '/page' }],
      tabs: [
        {
          title: 'Tab',
          link: '/page/tab',
          snapshotKey,
          content: <span>{label}</span>,
        },
      ],
    })

    describe('WHEN content changes but no snapshotKey is set', () => {
      it('THEN the stale content is kept (the bug this guards against)', () => {
        let captured: unknown = null

        const { rerender } = render(
          <MainHeaderProvider>
            <MainHeaderConfigure {...makeConfig('OLD')} />
            <ReadTabContentSpy onContent={(c) => (captured = c)} />
          </MainHeaderProvider>,
        )

        expect(captured).toEqual(<span>OLD</span>)

        rerender(
          <MainHeaderProvider>
            <MainHeaderConfigure {...makeConfig('NEW')} />
            <ReadTabContentSpy onContent={(c) => (captured = c)} />
          </MainHeaderProvider>,
        )

        // No snapshotKey change → setConfig skipped → context still holds OLD content.
        expect(captured).toEqual(<span>OLD</span>)
      })
    })

    describe('WHEN content changes together with snapshotKey', () => {
      it('THEN the fresh content is pushed to context', () => {
        let captured: unknown = null

        const { rerender } = render(
          <MainHeaderProvider>
            <MainHeaderConfigure {...makeConfig('OLD', 'a')} />
            <ReadTabContentSpy onContent={(c) => (captured = c)} />
          </MainHeaderProvider>,
        )

        expect(captured).toEqual(<span>OLD</span>)

        rerender(
          <MainHeaderProvider>
            <MainHeaderConfigure {...makeConfig('NEW', 'b')} />
            <ReadTabContentSpy onContent={(c) => (captured = c)} />
          </MainHeaderProvider>,
        )

        // snapshotKey changed → setConfig fires → context holds NEW content.
        expect(captured).toEqual(<span>NEW</span>)
      })
    })
  })

  describe('GIVEN the config changes', () => {
    describe('WHEN a new breadcrumb is provided', () => {
      it('THEN should update the context config', () => {
        const ReadConfigSpy: FC<{ onConfig: (config: MainHeaderConfig | null) => void }> = ({
          onConfig,
        }) => {
          const { config } = useMainHeaderReader()

          onConfig(config)

          return null
        }

        let capturedConfig: MainHeaderConfig | null = null

        const firstBreadcrumb = [{ label: 'First', path: '/first' }]
        const updatedBreadcrumb = [{ label: 'Updated', path: '/updated' }]

        const { rerender } = render(
          <MainHeaderProvider>
            <MainHeaderConfigure breadcrumb={firstBreadcrumb} />
            <ReadConfigSpy onConfig={(c) => (capturedConfig = c)} />
          </MainHeaderProvider>,
        )

        expect(capturedConfig).toEqual(expect.objectContaining({ breadcrumb: firstBreadcrumb }))

        rerender(
          <MainHeaderProvider>
            <MainHeaderConfigure breadcrumb={updatedBreadcrumb} />
            <ReadConfigSpy onConfig={(c) => (capturedConfig = c)} />
          </MainHeaderProvider>,
        )

        expect(capturedConfig).toEqual(expect.objectContaining({ breadcrumb: updatedBreadcrumb }))
      })
    })
  })

  describe('GIVEN an entity whose metadata is a ReactNode', () => {
    describe('WHEN computing the change-detection snapshot', () => {
      it('THEN should not crash on the non-serializable element and should push the node to context', () => {
        const ReadConfigSpy: FC<{ onConfig: (config: MainHeaderConfig | null) => void }> = ({
          onConfig,
        }) => {
          const { config } = useMainHeaderReader()

          onConfig(config)

          return null
        }

        let capturedConfig: MainHeaderConfig | null = null
        const metadataNode = <span>ext-id-copyable</span>

        // Before the snapshot fix, JSON.stringify on the element's circular
        // _owner Fiber threw "Converting circular structure to JSON".
        expect(() =>
          render(
            <MainHeaderProvider>
              <MainHeaderConfigure entity={{ viewName: 'Customer', metadata: metadataNode }} />
              <ReadConfigSpy onConfig={(c) => (capturedConfig = c)} />
            </MainHeaderProvider>,
          ),
        ).not.toThrow()

        expect(capturedConfig).toEqual(
          expect.objectContaining({
            entity: expect.objectContaining({ metadata: metadataNode }),
          }),
        )
      })
    })
  })
})
