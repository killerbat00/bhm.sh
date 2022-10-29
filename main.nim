import
    asyncdispatch,
    asynchttpserver,
    mimetypes,
    nativesockets,
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
        title: string
        address: string
        name: string
        version: string
        domain: Domain
        printLogging: bool

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
        requestStartTime: float
        data: TemplateData

    RouteHandler = proc(req: Request, ctx: RequestContext): HttpResponse {.gcsafe.}
    RouteTable = Table[string, RouteHandler]

proc addRoute(rt: ref RouteTable, route: string, handler: RouteHandler): void =
    if rt == nil:
        return

    if rt.contains(route):
        echo fmt"{route} already in RouteTable."
        return
    else:
        rt[route] = handler

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
    var included_content = initTable[string, string]()

    # first, find all directories in the layouts dir
    # and read the files they contain; these can be
    # included in layouts.
    for entry in walkDirRec("layouts", {pcDir}):
        for entry2 in walkDirRec(entry, {pcDir, pcFile}):
            if dirExists(entry2):
                continue
            included_content[entry2] = staticRead(entry2)

    # then, find all the actual layouts.
    for entry in walkDirRec("layouts", {pcFile}):
        if included_content.hasKey(entry):
            continue
        layouts[entry] = staticRead(entry)

    # finally, embed content in the layout files
    # if the layout embeds that content.
    for layout, layout_content in layouts.mpairs():
        result[layout] = layout_content
        for incl_file in included_content.keys():
            result[layout] = result[layout].replace("{{#" & incl_file & "}}", included_content[incl_file])

# Read all dynamic files from the dynamic/ dir.
# The content of these files can be dynamically
# modified for each request.
# These files are keyed by their filename as
# well as filename without extension.
proc slurpDynamicFiles: Table[string, string] =
    result = initTable[string, string]()
    for entry in walkDirRec("dynamic", {pcFile}):
        let contents = staticRead(entry)
        result[entry] = contents
        result[entry.splitFile[1]] = contents
#-- End compile time behavior

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

proc sendDynamicFile(req: Request, ctx: RequestContext, layout: string): HttpResponse {.gcsafe.}=
    var data = ctx.data
    var rendered = layout.multiReplace(@[
        ("{{#pageTitle}}", "Brian's " & data.pageTitle),
        ("{{#canonicalLink}}", data.canonicalLink),
        ("{{#chyron}}", data.chyron),
        ("{{#content}}", data.content)
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

const STATIC_FILES = slurpStaticFiles()
const LAYOUTS = slurpLayouts()
const DYNAMIC_FILES = slurpDynamicFiles()
const GEN_STRING = "Generated by <a target=\"_blank\" href=\"https://github.com/killerbat00/bhm.sh\">my custom webserver</a> written in <a href='https://nim-lang.org'>Nim</a> in $1 ms"
const MAIN_LAYOUT = "layouts/main.bhml"

proc serve(settings: Settings, routes: ref RouteTable) =
    let server = newAsyncHttpServer()
    var htmlContentHeader = @[("Content-Type", "text/html"), ("Content-Language", "en-US")]
    greetings(settings)

    proc handleRequest(req: Request): Future[void] {.async, gcsafe.} =
        var data = TemplateData(pageTitle: sample(titles.titles), chyron: sample(titles.chyrons), quote: sample(quotes.quotes))
        var ctx = RequestContext(htmlContentHeader: htmlContentHeader, generationString: GEN_STRING, requestStartTime: cpuTime(), data: data)
        var res: HttpResponse

        try:
            req.printInfo()
            let path = req.url.path[1 .. ^1] # full URL, for static files
            let route = toSeq(req.url.path.split("/"))[1 .. ^1] # always starts with `/`; discard first item

            if (path in STATIC_FILES):
                res = sendStaticFile(req, STATIC_FILES, settings.mimes)
            else:
                # ignore QSP
                if req.url.query.len > 0:
                    return req.respond(Http500, "", @[].newHttpHeaders)

                # and requests to pages deeper than the root
                if route.len > 1:
                    return req.respond(Http301, "", @[("Location", fmt"/{route[0]}")].newHttpHeaders)

                let requestedUrl = route[0]
                let inRouter = (requestedUrl in routes)
                let inDynamic = (requestedUrl in DYNAMIC_FILES)

                # womp, not in the router or dynamic files. 404
                if (not (inRouter or inDynamic)):
                    data.content = DYNAMIC_FILES["404"]
                    res = sendDynamicFile(req, ctx, LAYOUTS[MAIN_LAYOUT])

                # we know this route, construct the canonical link
                data.canonicalLink = "<link rel=\"canonical\" href=\"http://bhm.sh/" & requestedUrl & "\">"
                # router
                if (inRouter):
                    res = routes[route[0]](req, ctx)
                # templated files
                elif (inDynamic):
                    data.content = DYNAMIC_FILES[route[0]]
                    res = sendDynamicFile(req, ctx, LAYOUTS[MAIN_LAYOUT])
        except:
            logException(settings)
            res = (code: Http500, content: "", headers: @[])

        if res.code != Http200:
            return req.respond(res.code, res.content, res.headers.newHttpHeaders)

        if req.headers.hasKey("Accept-Encoding") and req.headers["Accept-Encoding"].contains("gzip"):
            res.headers.add(("Content-Encoding", "gzip"))
            let content = compress(res.content, BestSpeed)
            return req.respond(res.code, content, res.headers.newHttpHeaders)
        else:
            return req.respond(res.code, res.content, res.headers.newHttpHeaders)

    asyncCheck server.serve(settings.port, handleRequest, settings.address, -1, settings.domain)

proc handleCtrlC() {.noconv.} =
    echo "\nExiting..."
    quit()

setControlCHook(handleCtrlC)

when isMainModule:
    let settings = Settings(
        mimes: newMimetypes(),
        port: Port(1992),   
        title: "bhm.sh",
        address: "0.0.0.0",
        name: "bhm.sh",
        version: "0.8",
        domain: AF_INET,
        printLogging: when defined(release): false else: true
    )

    var addrInfo = getAddrInfo(settings.address, settings.port, settings.domain)
    if addrInfo == nil:
        echo "Error: Could not resolve address '" & settings.address & "'."
        quit(1)

    proc index(req: Request, ctx: RequestContext): HttpResponse {.gcsafe.} =
        ctx.data.canonicalLink = "<link rel=\"canonical\" href=\"http://bhm.sh/\">"
        ctx.data.content = DYNAMIC_FILES["index"].multiReplace(@[
            ("{{#quoteText}}", ctx.data.quote.quote),
            ("{{#quoteAuthor}}", ctx.data.quote.author),
            ("{{#quoteCitation}}", ctx.data.quote.citation)
        ])
        return sendDynamicFile(req, ctx, LAYOUTS[MAIN_LAYOUT])

    randomize()
    let routes = new(RouteTable)
    routes.addRoute("", index)
    routes.addRoute("/", index)
    routes.addRoute("index", index)
    routes.addRoute("index.html", index)
    serve(settings, routes)
    runForever()
