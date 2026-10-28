#!/bin/sh
# usage: build.sh eN  -> builds eN.swift as main into the probe bundle, then runs it
cd "$(dirname "$0")"; mkdir -p b KomoraProbe.app/Contents/MacOS; cp "$1.swift" b/main.swift; cp common.swift b/common.swift
swiftc -O b/common.swift b/main.swift -o KomoraProbe.app/Contents/MacOS/KomoraProbe 2>&1 | grep -E "error" && exit 1
./KomoraProbe.app/Contents/MacOS/KomoraProbe 2>&1 | grep -v -E "^\s*$"
