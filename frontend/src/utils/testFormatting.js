export const testMarkdownParsing = () => {
  const testCases = [
    {
      name: "Negrita simple",
      input: "Esto es **negrita** en texto",
      expected: "Debe mostrar 'negrita' en bold",
    },
    {
      name: "Lista con negritas",
      input: "- **Título**: Descripción aquí",
      expected: "Debe mostrar Título en bold dentro de lista",
    },
    {
      name: "Saltos de línea",
      input: "Línea 1\\n\\nLínea 2",
      expected: "Debe haber espacio entre líneas",
    },
  ]

  testCases.forEach((test) => {
    console.log(`\n📝 Test: ${test.name}`)
    console.log(`Input: "${test.input}"`)
    console.log(`Esperado: ${test.expected}`)
  })
}
