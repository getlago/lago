export default function (file, api) {
  // Alias the jscodeshift API for ease of use.
  const j = api.jscodeshift

  // Convert the entire file source into a collection of nodes paths.
  const root = j(file.source)

  root
    // Find all Skeleton JSX elements
    .findJSXElements('Skeleton')
    .filter((path) => {
      // ...with a width attribute defined
      const hasWidthDefined = path.value.openingElement.attributes.some(
        (attr) => attr.name.name === 'width',
      )

      return hasWidthDefined
    })
    .forEach((path) => {
      // Create a map of margin values
      let className = ''

      path.value.openingElement.attributes.forEach((attr) => {
        //         if (attr.name.name === 'width') {
        //           console.log(
        //             attr,
        //             `
        // ------------------------------------------------------------------------------------------------------------------------------------------------------
        // ------------------------------------------------------------------------------------------------------------------------------------------------------
        // ------------------------------------------------------------------------------------------------------------------------------------------------------
        // ------------------------------------------------------------------------------------------------------------------------------------------------------
        // ------------------------------------------------------------------------------------------------------------------------------------------------------
        //             `,
        //           )

        if (
          attr.value.type === 'JSXExpressionContainer' &&
          attr.value.expression.type === 'NumericLiteral'
        ) {
          let localValue = attr.value.expression.value

          let i = 10

          while (localValue % 4 !== 0 && i !== 0) {
            if (localValue < 4) {
              localValue = 4
              break
            } else {
              localValue -= 1
              i--
            }
          }

          className = `w-${localValue / 4}`
        } else if (
          attr.value.type === 'StringLiteral' &&
          (attr.value.value === '100%' || attr.value.value === 'inherit')
        ) {
          className = ''
        } else if (attr.value.type === 'StringLiteral' && attr.value.value.includes('%')) {
          className = `w-[${attr.value.value}]`
        }
      })

      // If element does not have className attribute, create it
      const hasClassName = path.value.openingElement.attributes.some(
        (attr) => attr.name.name === 'className',
      )

      if (!hasClassName) {
        // push new classNames to the element
        path.value.openingElement.attributes.push(
          j.jsxAttribute(j.jsxIdentifier('className'), j.stringLiteral(className)),
        )
      } else {
        // If element has className attribute, update it
        path.value.openingElement.attributes = path.value.openingElement.attributes.map((attr) => {
          if (attr.name.name === 'className') {
            attr.value.value += ` ${className}`
          }

          return attr
        })
      }

      // remove width related attributes
      path.value.openingElement.attributes = path.value.openingElement.attributes.filter(
        (attr) => attr.name.name !== 'width',
      )
    })

  // Save changes to the file
  return root.toSource()
}
