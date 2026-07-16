export const scrollToFirstInputError = (formId: string, errorMap: Record<string, unknown>) => {
  const inputs: HTMLInputElement[] = Array.from(
    // Must match the selector used in your form
    document.querySelectorAll(`#${formId} input`),
  )

  const firstInput = inputs.find((input) => {
    const fieldErrors = errorMap[input.name]

    return !!fieldErrors
  })

  if (firstInput?.isConnected) {
    firstInput.scrollIntoView({ behavior: 'smooth', block: 'center' })
    // Timeout just to ensure scrolling has finished
    setTimeout(() => {
      // Check if element still exists in the DOM before focusing
      if (firstInput.isConnected) {
        firstInput.focus()
      }
    }, 300)
  }
}
