/**
 * ESLint rule to forbid importing `useNavigate`, `Link`, `useLocation`, and
 * `useMatch` directly from `react-router-dom`. These must be imported from
 * `~/core/router` so the org slug is automatically prepended (for
 * `useNavigate`/`Link`) or `strippedPathname` is available (for
 * `useLocation`). `useMatch` is banned because it matches against the
 * full pathname (including the slug prefix), so route constants never
 * match — use `matchPath` + `strippedPathname` instead.
 *
 * Exceptions (auth callbacks, Error404, and the wrappers themselves) can
 * opt out with an `// eslint-disable-next-line` comment on the import.
 */

const RESTRICTED = new Set(['useNavigate', 'Link', 'useLocation', 'useMatch'])

export default {
  meta: {
    type: 'problem',
    docs: {
      description:
        "Disallow importing useNavigate, Link, useLocation, and useMatch from 'react-router-dom'. Use '~/core/router' for slug-aware wrappers. useMatch is banned — use matchPath + strippedPathname instead.",
      recommended: true,
    },
    fixable: null,
    schema: [],
    messages: {
      noDirectImport:
        "Import '{{name}}' from '~/core/router' instead of 'react-router-dom' to ensure the org slug is prepended automatically (useNavigate/Link) or strippedPathname is available (useLocation). useMatch is banned — use matchPath + strippedPathname instead.",
    },
  },
  create(context) {
    return {
      ImportDeclaration(node) {
        if (node.source.value !== 'react-router-dom') return

        for (const specifier of node.specifiers) {
          if (specifier.type !== 'ImportSpecifier') continue
          const imported = specifier.imported?.name

          if (RESTRICTED.has(imported)) {
            context.report({
              node: specifier,
              messageId: 'noDirectImport',
              data: { name: imported },
            })
          }
        }
      },
    }
  },
}
