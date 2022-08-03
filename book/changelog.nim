import nimib, nimibook


nbInit(theme = useNimibook)

nbText: readFile("../changelog.md")

nbSave
