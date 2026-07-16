import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { HOME_ROUTE } from '~/core/router'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import ErrorImage from '~/public/images/maneki/error.svg'

const Error404 = () => {
  const { translate } = useInternationalization()

  /**
   * Hard-navigate via `window.location.href` instead of `navigate(HOME_ROUTE)`.
   *
   * Rationale — stale SPA bundle after a deploy:
   * A user with the app already open in a tab keeps the old JS bundle in
   * memory. When a new version is deployed and the URL structure changes
   * (e.g. the org-slug migration), in-app navigations from the stale bundle
   * produce paths the new router doesn't match and the user lands here.
   * An SPA `navigate` call stays on the stale bundle and lands on this same
   * 404 again. A full-page navigation forces the browser to fetch the new
   * `index.html` and the current bundle, unblocking the user in one click.
   *
   * Safe to keep post-migration: a hard reload from a 404 is indistinguishable
   * UX-wise from an SPA navigation, and protects against any future deploy
   * that changes route shapes.
   */
  const goHome = () => {
    window.location.href = HOME_ROUTE
  }

  return (
    <div className="flex h-screen w-screen">
      <GenericPlaceholder
        image={<ErrorImage width="136" height="104" />}
        title={translate('text_62bac37900192b773560e82d')}
        subtitle={translate('text_62bac37900192b773560e82f')}
        buttonTitle={translate('text_62bac37900192b773560e831')}
        buttonAction={goHome}
      />
    </div>
  )
}

export default Error404
