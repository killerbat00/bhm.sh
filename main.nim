import
    asyncdispatch,
    asynchttpserver,
    mimetypes,
    nativesockets,
    options,
    os,
    random,
    sequtils,
    strutils,
    strformat,
    tables,
    times,
    uri,
    zippy

from httpcore import
    HttpMethod,
    HttpHeaders

from quotes import quotes
from titles import titles, chyrons

type
    HttpResponse = tuple[
        code: HttpCode,
        content: string,
        headers: seq[(string, string)]]

    Settings = ref object
        mimes: MimeDB
        port: Port
        address: string
        name: string
        version: string
        domain: Domain

    TemplateData = ref object
        pageTitle: string
        canonicalLink: string
        chyron: string
        content: string
        quote: tuple[
            quote: string,
            author: string,
            citation: string]

    RequestContext = ref object
        htmlContentHeader: seq[(string, string)]
        generationString: string
        sillyString: string
        requestStartTime: float
        data: TemplateData

    ArticleDetails = tuple[
        content: string,
        createdAt: Option[times.Time],
        lastUpdated: Option[times.Time],
    ]

    RouteHandler = proc(req: Request, ctx: RequestContext): HttpResponse {.gcsafe.}
    RouteTable = Table[string, RouteHandler]

#-- Compile time behavior
# Reads all files from the static/ dir into a
# table keyed by their filename. These files are served
# directly.
proc slurpStaticFiles: Table[string, string] =
    result = initTable[string, string]()
    for entry in walkDirRec("static", {pcFile, pcDir}):
        if dirExists(entry):
            continue
        result[entry] = staticRead(entry)

# Read and assemble all layouts from the layouts/ dir.
proc slurpLayouts: Table[string, string] =
    result = initTable[string, string]()
    var layouts = initTable[string, string]()
    var includedContent = initTable[string, string]()

    # first, find all directories in the layouts dir
    # and read the files they contain; these can be
    # included in layouts.
    for entry in walkDirRec("layouts", {pcDir}):
        for entry2 in walkDirRec(entry, {pcDir, pcFile}):
            if dirExists(entry2):
                continue
            includedContent[entry2] = staticRead(entry2)

    # then, find all the actual layouts.
    for entry in walkDirRec("layouts", {pcFile}):
        if includedContent.hasKey(entry):
            continue
        layouts[entry] = staticRead(entry)

    # finally, embed content in the layout files
    # if the layout embeds that content.
    for layout, layoutContent in layouts.mpairs():
        result[layout] = layoutContent
        for inclFile in includedContent.keys():
            result[layout] = result[layout].replace("{{#" & inclFile & "}}", includedContent[incl_file])

# Read all dynamic files from the dynamic/ dir.
# The content of these files can be dynamically
# modified for each request.
# These files are keyed by their filename as
# well as filename without extension.
proc slurpDynamicFiles: Table[string, string] =
    result = initTable[string, string]()
    for entry in walkDirRec("dynamic", {pcFile}):
        let contents = staticRead(entry)
        let (_, name, ext) = entry.splitFile()
        result[name & ext] = contents
        result[name] = contents

# Read all articles from articles/
# Though the extension is ignored, these are
# treated as markdown.
proc slurpArticles: Table[string, ArticleDetails] =
    result = initTable[string, ArticleDetails]()
    for entry in walkDirRec("articles", {pcFile}):
        let name = entry.splitFile()[1]
        let contents = staticRead(entry)
        result[name] = (content: contents, createdAt: none(times.Time), lastUpdated: none(times.Time))
    #-- End compile time behavior

proc addRoute(rt: ref RouteTable, route: string, handler: RouteHandler): void =
    if rt == nil:
        return

    if rt.contains(route):
        when not defined(release):
            echo fmt"{route} already in RouteTable."
    else:
        rt[route] = handler

proc addRoute(rt: ref RouteTable, routes: seq[string], handler: RouteHandler): void =
    if rt == nil:
        return

    for route in routes:
        rt.addRoute(route, handler)

proc sendStaticFile(req: Request, staticFiles: Table[string, string], mimes: MimeDB): HttpResponse {.gcsafe.} =
    let
        url = req.url.path[1 .. ^1]
        ext = url.splitFile.ext
        file = staticFiles[url]
    var mimetype = mimes.getMimetype(ext.toLowerAscii)

    # .js.map files incorrectly map to x-navimap. fix it.
    if (mimetype == "application/x-navimap"):
        mimetype = "application/json"

    return (code: Http200, content: file, headers: @[("Content-Type", mimetype)])

proc sendDynamicFile(req: Request, ctx: RequestContext, layout: string): HttpResponse {.gcsafe.} =
    var data = ctx.data
    var rendered = layout.multiReplace(@[
        ("{{#pageTitle}}", "Brian's " & data.pageTitle),
        ("{{#canonicalLink}}", data.canonicalLink),
        ("{{#chyron}}", data.chyron),
        ("{{#content}}", data.content),
        ("{{#sillyString}}", ctx.sillyString)
    ])

    let
        timeTaken = (cpuTime() - ctx.requestStartTime) * 1000
        finalContent = rendered.replace("{{#generationString}}", ctx.generationString % $timeTaken.formatFloat(ffDecimal, 5))

    return (code: Http200, content: finalContent, headers: ctx.htmlContentHeader)

proc greetings(settings: Settings): void =
    let url = "http://$1:$2/" % [settings.address, $settings.port.int]
    let t = now()
    let pid = getCurrentProcessId()
    echo fmt"""{settings.name} v{settings.version}
Address:      {url}
Current Time: {$t}
PID:          {$pid}"""

proc printInfo(req: Request) =
    when not defined(release):
        echo fmt"{getTime().local} - {req.hostname} {req.reqMethod} {req.url.path} {req.url.query}"

proc logException(settings: Settings) =
    let
        e = getCurrentException()
        msg = getCurrentExceptionMsg()
    echo fmt"{repr(e)}\n{repr(msg)}"
    writeStackTrace()

proc sendResponse(req: Request, res: HttpResponse) {.gcsafe, async.} =
    if req.headers.hasKey("Accept-Encoding") and req.headers["Accept-Encoding"].contains("gzip"):
        let h = res.headers.newHttpHeaders
        h.add("Content-Encoding", "gzip")
        let content = compress(res.content, BestSpeed)
        await req.respond(res.code, content, h)
    else:
        await req.respond(res.code, res.content, res.headers.newHttpHeaders)

const STATIC_FILES: Table[string, string] = slurpStaticFiles()
const LAYOUTS = slurpLayouts()
const DYNAMIC_FILES = slurpDynamicFiles()
const ARTICLES = slurpArticles()
const VERSION = "2022.12.15c"
const VERSION_URL = "https://github.com/killerbat00/bhm.sh/releases/tag/v$1" % VERSION
const VERSION_LINK = fmt"<a target='_blank' href='{VERSION_URL}' title='Link to current webserver release tag'>{VERSION}</a>"
const GEN_STRING = "Generated by <a target='_blank' href='https://github.com/killerbat00/bhm.sh' title='Link to webserver source code'>my custom webserver</a> written in <a href='https://nim-lang.org' target='_blank' title='Link to the Nim programming language website'>Nim</a> in $1 ms"
const SILLY_STRING = "Made with 🐶 Einstein (my dog). v$1." % VERSION_LINK
const MAIN_LAYOUT = "layouts/main.bhml"

proc serve(settings: Settings, routes: ref RouteTable) =
    let server = newAsyncHttpServer()
    var htmlContentHeader = @[("Content-Type", "text/html"), ("Content-Language", "en-US")]
    greetings(settings)

    proc handleRequest(req: Request): Future[void] {.async, gcsafe.} =
        var data = TemplateData(pageTitle: sample(titles.titles), chyron: sample(titles.chyrons), quote: sample(quotes.quotes))
        var ctx = RequestContext(htmlContentHeader: htmlContentHeader, generationString: GEN_STRING, requestStartTime: cpuTime(), data: data, sillyString: SILLY_STRING)
        var res: HttpResponse

        try:
            req.printInfo()
            let path = req.url.path[1 .. ^1] # full URL, for static files
            let route = toSeq(req.url.path.split("/"))[1 .. ^1] # always starts with `/`; discard first item

            if (path in STATIC_FILES):
                res = sendStaticFile(req, STATIC_FILES, settings.mimes)
                await sendResponse(req, res)
                return

            # ignore QSP
            if req.url.query.len > 0:
                await req.respond(Http500, "", @[].newHttpHeaders)
                return

            let requestedUrl = route[0].splitFile[1]
            let inRouter = (requestedUrl in routes)
            let inDynamic = (requestedUrl in DYNAMIC_FILES)

            # router
            if (inRouter):
                res = routes[route[0]](req, ctx)
            # templated files
            elif (inDynamic):
                # we know this route, construct the canonical link
                ctx.data.canonicalLink = "<link rel=\"canonical\" href=\"https://bhm.sh/" & requestedUrl & "\">"
                ctx.data.content = DYNAMIC_FILES[route[0]]
                res = sendDynamicFile(req, ctx, LAYOUTS[MAIN_LAYOUT])
            else:
                # womp, not in the router or dynamic files,
                await req.respond(Http404, DYNAMIC_FILES["404"], ctx.htmlContentHeader.newHttpHeaders)
                return

        except:
            logException(settings)
            res = (code: Http500, content: "", headers: @[])

        if res.code != Http200:
            await req.respond(res.code, res.content, res.headers.newHttpHeaders)
            return

        await sendResponse(req, res)
    asyncCheck server.serve(settings.port, handleRequest, settings.address, -1, settings.domain)


proc handleCtrlC() {.noconv.} =
    echo "\nExiting..."
    quit()

setControlCHook(handleCtrlC)

when isMainModule:
    let settings = Settings(
        mimes: newMimetypes(),
        port: Port(1992),
        address: "0.0.0.0",
        name: "bhm.sh",
        version: VERSION,
        domain: AF_INET,
    )

    var addrInfo = getAddrInfo(settings.address, settings.port, settings.domain)
    if addrInfo == nil:
        echo "Error: Could not resolve address '" & settings.address & "'."
        quit(1)

    proc index(req: Request, ctx: RequestContext): HttpResponse {.gcsafe.} =
        ctx.data.canonicalLink = "<link rel=\"canonical\" href=\"https://bhm.sh/\">"
        ctx.data.content = DYNAMIC_FILES["index"].multiReplace(@[
            ("{{#quoteText}}", ctx.data.quote.quote),
            ("{{#quoteAuthor}}", ctx.data.quote.author),
            ("{{#quoteCitation}}", ctx.data.quote.citation)
        ])
        return sendDynamicFile(req, ctx, LAYOUTS[MAIN_LAYOUT])

    proc extras(req: Request, ctx: RequestContext): HttpResponse {.gcsafe.} =
        let route = toSeq(req.url.path.split("/"))[1 .. ^1] # always starts with `/`; discard first item
        if (route.len == 1):
            ctx.data.canonicalLink = "<link rel=\"canonical\" href=\"https://bhm.sh/blog\">"
            ctx.data.content = fmt"""
            <div>{ARTICLES.len} articles</div>
            """
            return sendDynamicFile(req, ctx, LAYOUTS[MAIN_LAYOUT])

        let articleName = route[1]
        if (not (articleName in ARTICLES)):
            return (code: Http404, content: DYNAMIC_FILES["404"], headers: ctx.htmlContentHeader)

        ctx.data.canonicalLink = "<link rel=\"canonical\" href=\"https://bhm.sh/blog/$1\">" % articleName
        ctx.data.content = ARTICLES[articleName].content
        return sendDynamicFile(req, ctx, LAYOUTS[MAIN_LAYOUT])




    randomize()
    let routes = new(RouteTable)
    routes.addRoute(@["", "/", "index", "index.html"], index)
    routes.addRoute(@["vault", "vault.html"], extras)
    serve(settings, routes)
    runForever()
