export default function (file, api) {
  // Alias the jscodeshift API for ease of use.
  const j = api.jscodeshift

  // Convert the entire file source into a collection of nodes paths.
  const root = j(file.source)

  root
    // Find all JSX elements with the name FontAwesomeIcon...
    .findJSXElements('Skeleton')
    .filter((path) => {
      // ...that have a variant text attribute...
      const hasVariant = path.value.openingElement.attributes.some(
        (attr) => attr.name.name === 'variant' && attr.value.value === 'text',
      )
      // ...and a height attribute with value 12
      const hasHeight = path.value.openingElement.attributes.some(
        (attr) => attr.name.name === 'height' && attr.value.expression.value === 12,
      )

      return hasVariant && hasHeight
    })
    // Get the height attribute node
    .find(j.JSXAttribute, {
      name: {
        type: 'JSXIdentifier',
        name: 'height',
      },
    })
    // Remove it
    .remove()

  // Save changes to the file
  return root.toSource()
}
