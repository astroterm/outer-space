set shell := ['nu', '-c']

CWD    := "..."
BUTANE := 'butane --pretty --strict'
SRC    := CWD / 'coreos/butane/config'
DST    := CWD / 'coreos/ignition'

render:
    {{BUTANE}} {{SRC}}/control-1.yaml -d {{CWD}}/coreos/butane | save -f {{DST}}/control-1.json
    {{BUTANE}} {{SRC}}/control-2.yaml -d {{CWD}}/coreos/butane | save -f {{DST}}/control-2.json
    {{BUTANE}} {{SRC}}/control-3.yaml -d {{CWD}}/coreos/butane | save -f {{DST}}/control-3.json
