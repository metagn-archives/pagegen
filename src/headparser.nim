import strutils

const
  NameSet = Letters + {'-', '_'}
  WhitespaceExceptNewlines = Whitespace - Newlines

proc recordName(str: string, i: var int): string =
  while i < str.len:
    if str[i] in NameSet:
      result.add(str[i])
    else:
      dec i
      return
    inc i

proc recordQuoted(str: string, i: var int): string =
  let quote = str[i]
  inc i
  var escaped = false
  while i < str.len:
    let ch = str[i]
    if escaped:
      result.add('\\')
      result.add(ch)
      escaped = false
    elif ch == quote:
      return
    elif ch == '\\':
      escaped = true
    else: result.add(ch)
    inc i

proc recordAttribute(str: string, i: var int): string =
  result.add(recordName(str, i))
  inc i
  var waitingForValue = false
  while i < str.len:
    let ch = str[i]
    if not waitingForValue:
      case ch
      of Newlines:
        dec i
        return
      of WhitespaceExceptNewlines: discard
      of '=':
        result.add('=')
        waitingForValue = true
      else:
        dec i
        return
    else:
      case ch
      of Newlines:
        result.add("\"\"")
        dec i
        return
      of NameSet:
        result.add('"')
        result.add(recordName(str, i))
        result.add('"')
        return
      of '\'', '"':
        result.add('"')
        result.add(recordQuoted(str, i))
        result.add('"')
        return
      else: discard
    inc i

proc recordBlockLine(str: string, i: var int): string =
  var escaped = false
  while i < str.len:
    let ch = str[i]
    if escaped:
      if ch in Newlines:
        result.add(' ')
      else:
        result.add('\\')
        result.add(ch)
      escaped = false
    elif ch == '\\':
      escaped = true
    elif ch in Newlines:
      return
    else: result.add(ch)
    inc i

proc recordBlock(str: string, indent: int, i: var int): string =
  var ind = 0
  result.add(recordBlockLine(str, i))
  while i < str.len:
    let ch = str[i]
    if ind >= indent:
      result.add("\r\n")
      result.add(recordBlockLine(str, i))
      ind = 0
    else:
      case ch
      of Newlines: ind = 0
      of WhitespaceExceptNewlines:
        inc ind
      else:
        dec i
        return
    inc i

proc recordColon(str: string, i: var int): string =
  while i < str.len:
    let ch = str[i]
    case ch
    of WhitespaceExceptNewlines:
      discard
    of '"', '\'':
      return recordQuoted(str, i)
    of Newlines:
      var indent = 0
      inc i
      while i < str.len and str[i] in WhitespaceExceptNewlines:
        inc indent
        inc i
      return recordBlock(str, indent, i)
    else:
      return recordBlockLine(str, i)
    inc i

proc recordElement(str: string, i: var int): string =
  type State = enum start, attrs
  var
    tagName: string
    state = start
  while i < str.len:
    let ch = str[i]
    case state
    of start:
      if ch in NameSet:
        result.add('<')
        tagName = recordName(str, i)
        result.add(tagName)
        state = attrs
      else:
        discard
    of attrs:
      case ch
      of NameSet:
        result.add(' ')
        result.add(recordAttribute(str, i))
      of Newlines:
        result.add("/>")
        return
      of ':', '=':
        result.add('>')
        inc i
        result.add(recordColon(str, i))
        result.add("</")
        result.add(tagName)
        result.add('>')
        return
      of '"':
        result.add('>')
        result.add(recordQuoted(str, i))
        result.add("</")
        result.add(tagName)
        result.add('>')
        return
      else: discard
    inc i

proc metaToHead*(meta: string): string =
  var i = 0
  while i < meta.len:
    result.add(recordElement(meta, i))
    inc i

when isMainModule:
  echo metaToHead"""
title: title here
title: "title here"
title "title here"
title:
  title here
  here
link rel="css" whatever=src
style:
  abc {
    def
  }
"""
