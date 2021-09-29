import nimib, nimibook


nbInit
nbUseNimibook

nbText: """
# Tutorial

Before going further, install [inim](https://github.com/inim-repl/INim) with nimble:

    $ nimble install -y inim

Also, make sure you have SQLite installed. On most Linux distributions, it should be preinstalled. To install SQLite in macOS, use [brew](https://brew.sh/). On Windows, use [scoop](https://scoop.sh/).

Then, start a new inim session:

    $ inim -d:normDebug
"""

nbSave
