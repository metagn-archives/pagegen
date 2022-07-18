import strutils, headparser

type
  PageKind* = enum
    pkAsset, pkMarkdown, pkRst, pkMarggers
  Page* = ref object
    case kind*: PageKind
    of pkMarkdown, pkRst, pkMarggers:
      meta*, body*: string
    of pkAsset: discard

const markups*: set[PageKind] = {pkMarkdown, pkRst, pkMarggers}
const supportedMarkups*: set[PageKind] = {pkMarggers}

when pkMarkdown in supportedMarkups:
  import markdown

when pkRst in supportedMarkups:
  import rstgen, rst, strtabs

when pkMarggers in supportedMarkups:
  import marggers/marggers

proc loadHypertext*(page: Page, name: string, file: File) =
  if page.kind notin markups: return
  var 
    line = ""
    recordMeta = false

  while file.readLine(line):
    if line.isEmptyOrWhitespace:
      continue
    elif line == "---":
      recordMeta = true
    else:
      page.body.add(line)
      page.body.add("\n")
    break
  if recordMeta:
    while file.readLine(line) and line != "---":
      page.meta.add(line)
      page.meta.add("\n")
  while file.readLine(line):
    page.body.add(line)
    page.body.add("\n")
  echo "File read: ", name
  file.close()

proc loadHypertext*(page: Page, text: string) =
  if page.kind notin markups: return
  let lines = text.splitLines
  var
    i = 0
    recordMeta = false

  while i < lines.len:
    let line = lines[i]
    inc i
    if line.isEmptyOrWhitespace:
      continue
    elif line == "---":
      recordMeta = true
    else:
      page.body.add(line)
      page.body.add("\n")
    break
  if recordMeta:
    while i < lines.len:
      let line = lines[i]
      inc i
      if line == "---":
        break
      else:
        page.meta.add(line)
        page.meta.add("\n")
  while i < lines.len:
    let line = lines[i]
    inc i
    page.body.add(line)
    page.body.add("\n")

proc genRst(body: string): string =
  when pkRst in supportedMarkups:
    result = rstToHtml(body, {roSupportMarkdown, roSupportRawDirective}, newStringTable(modeStyleInsensitive))
  else:
    raise newException(ValueError, "rst not supported")

proc genMd(body: string): string =
  when pkMarkdown in supportedMarkups:
    result = markdown(body)
  else:
    raise newException(ValueError, "markdown not supported")

proc genMg(body: string): string =
  when pkMarggers in supportedMarkups:
    for b in parseMarggers(body):
      result.add($b)
  else:
    raise newException(ValueError, "rst not supported")

proc toHtml*(page: Page, tmpl: string): string =
  result = tmpl.multiReplace({
    "$head": metaToHead(page.meta),
    "$body": case page.kind
             of pkMarkdown: genMd(page.body)
             of pkRst: genRst(page.body)
             of pkMarggers: genMg(page.body)
             else: ""
  })

when isMainModule:
  echo metaToHead("""base(href="http://metagod.gq/" target="_blank")""")
