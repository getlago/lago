/**
 * ESLint rule to prevent formikProps from being used as a dependency in React hooks.
 * This prevents infinite re-rendering loops since formikProps is a new object reference on every render.
 * Also, this rule should be used as long as we are using Formik in the project.
 */

const HOOKS_WITH_DEPENDENCIES = ['useEffect'] // this may be extended in the future to include other hooks

export default {
  meta: {
    type: 'problem',
    docs: {
      description:
        'Disallow formikProps as a dependency in React ({{hookName}}) hooks to prevent infinite re-rendering loops',
      category: 'Possible Errors',
      recommended: true,
    },
    fixable: null,
    schema: [],
    messages: {
      noFormikPropsInEffect:
        'formikProps should not be used as a dependency in {{hookName}}. It causes infinite re-rendering loops. Use specific formikProps properties instead (e.g., formikProps.values, formikProps.setFieldValue).',
    },
  },
  create(context) {
    /**
     * Checks if a node is a formikProps identifier
     */
    function isFormikProps(node) {
      return node && node.type === 'Identifier' && node.name === 'formikProps'
    }

    /**
     * Checks if a node contains formikProps as a direct dependency (not as a property access)
     * We allow formikProps.something but not formikProps directly
     */
    function containsFormikProps(node) {
      if (!node) return false

      // Direct identifier: formikProps (this is what we want to catch)
      if (isFormikProps(node)) {
        return true
      }

      // Member expression: formikProps.something (this is allowed, so we don't check deeper)
      if (node.type === 'MemberExpression') {
        // Only check if the object itself is formikProps directly
        // If it's a nested property access, we allow it
        return false
      }

      // Array expression: check all elements
      if (node.type === 'ArrayExpression') {
        return node.elements.some((element) => containsFormikProps(element))
      }

      return false
    }

    return {
      CallExpression(node) {
        // Check if this is a React hook call with dependencies
        if (node.callee && node.callee.type === 'Identifier') {
          const hookName = node.callee.name

          if (HOOKS_WITH_DEPENDENCIES.includes(hookName)) {
            // These hooks have two arguments: callback/factory and dependencies array
            const dependencies = node.arguments[1]

            // Check if formikProps is in dependencies (should not be)
            if (dependencies && containsFormikProps(dependencies)) {
              context.report({
                node: dependencies,
                messageId: 'noFormikPropsInEffect',
                data: {
                  hookName,
                },
              })
            }
          }
        }
      },
    }
  },
}
