switch("path", "$projectDir/../src")
switch("verbosity", "0")
switch("hints", "off")
when (NimMajor, NimMinor) >= (1, 1):
  switch("gc", "arc")
  switch("panics", "on")
