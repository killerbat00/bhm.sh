import 
    asyncdispatch,
    asynchttpserver, 
    mimetypes, 
    nativesockets,
    os,
    random,
    sequtils,
    strutils,
    times, 
    uri,
    tables

from httpcore import HttpMethod, HttpHeaders

type 
    HttpResponse = tuple[
        code: HttpCode,
        content: string,
        headers: HttpHeaders]

    Settings = object
        mimes: MimeDB
        port: Port
        title: string
        address: string
        name: string
        version: string
        files: Table[string, string]
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

const validDirs = ["static/fonts", "static/js", "static/styles", "static/templates", "static/img"]
const mainTemplate = staticRead("static/layouts/mainTemplate.html")


# gzip/brotli the files eventually - that'd be cool
proc slurpFiles(): Table[string, string] =
    result = initTable[string, string]()
    for dir in walkDirRec("static", {pcDir}):
        if not (dir in validDirs):
            continue

        let public_dir = dir == "static/templates"
        for file in walkDirRec(dir):
            var contents = staticRead(file)
            if public_dir:
                result[file.splitFile[1]] = contents
            else:
                result[file] = contents

const files = slurpFiles()
const titles = ["cabin in the woods", "slice of the internet", "home on the World Wide Web", "bytes", "virtual space", "website", "page", "country corner", "internet of things", "is the place to be", "personal digital destination", "home for wayward dogs", "home of horrors (NOT scary)"]
const chyrons = ["Now in technicolor", "...oh, this is still here?", "fueled by Diet Mtn Dew", "allegedly", "dog hair now included!", "enjoy your stay!", "FREE bits AND bytes!"]
const genString = "Generated by my custom webserver written in <a href='https://nim-lang.org'>Nim</a> in $1 ms"
const quotes = [
    ("Every era puts invisible shackles on those who have lived through it, and I can only dance in my chains.", "Liu Cixin", "<i>The Three-Body Problem</i>"),
    ("""I must not fear.
<br>Fear is the mind-killer.
<br>Fear is the little-death that brings total obliteration.
<br>I will face my fear.
<br>I will permit it to pass over me and through me.
<br>And when it has gone past, I will turn the inner eye to see its path.
<br>Where the fear has gone there will be nothing. Only I will remain.""", "Frank Herbert", "<i>Dune</i>"),
    ("The mystery of life isn't a problem to solve, but a reality to experience.", "Frank Herbert", "<i>Dune</i>"),
    ("Deep in the human unconscious is a pervasive need for a logical universe that makes sense. But the real universe is always one step beyond logic.", "Frank Herbert", "<i>Dune</i>"),
    ("It is impossible to live in the past, difficult to live in the present and a waste to live in the future.", "Frank Herbert", "<i>Dune</i>"),
    ("He who controls the spice controls the universe.", "Frank Herbert", "<i>Dune</i>"),
    ("Sometimes I can hear my bones straining under the weight of all the lives I'm not living.", "Jonathan Safran Foer", "<i>Extremely Loud & Incredibly Close</i>"),
    ("I regret that it takes a life to learn how to live.", "Jonathan Safran Foer", "<i>Extremely Loud & Incredibly Close</i>"),
    ("Songs are as sad as the listener.", "Jonathan Safran Foer", "<i>Extremely Loud & Incredibly Close</i>"),
    ("So many people enter and leave your life! Hundreds of thousands of people! You have to keep the door open so they can come in! But it also means you have to let them go!", "Jonathan Safran Foer", "<i>Extremely Loud & Incredibly Close</i>"),
    ("My life story is the story of everyone I've ever met.", "Jonathan Safran Foer", "<i>Extremely Loud & Incredibly Close</i>"),
    ("One morning, over at Elizabeth’s beach house, she asked me if I’d rather go water-skiing or lay out. And I realized that not only did I not want to answer THAT question, but I never wanted to answer another water-sports question, or see any of these people again for the rest of my life.", "Anthony", "<i>Bottle Rocket</i>"),
    ("I know, honey. Look at the map. We go your way, that’s about four inches. We go my way, it’s an inch and a half. You wanna pay for the extra gas?", "Steve Zissou", "<i>The Life Aquatic with Steve Zissou</i>"),
    ("Why a fox? Why not a horse, or a beetle, or a bald eagle? I’m saying this more as, like, existentialism, you know? Who am I? And how can a fox ever be happy without, you’ll forgive the expression, a chicken in its teeth?", "Mr. Fox", "<i>Fantastic Mr. Fox</i>"),
    ("You know I'm not big on apologizing. So I'll just skip it if it's all the same to you. [OK.] Anyway, I'm sorry.", "Steve Zissou", "<i>The Life Aquatic with Steve Zissou</i>"),
    ("It's a luscious mix of words and tricks that let us bet when you know we should fold.", "The Shins", """"Caring is Creepy""""),
    ("Faced with the dodo's conundrum I felt like I could just fly, but nothing happened every time I'd try.", "The Shins", """"Australia""""),
    ("""Turn me back into the pet I was when we met.
<br>I was happier then with no mind-set.""", "The Shins", """"New Slang""""),
    ("""Held to the past, too aware of the pending
<br>Chill as the dawn breaks and finds us up for sale
<br>Enter the fog another low road descending
<br>Away from the cold lust, you house and summertime.""", "The Shins", """"The Past and Pending""""),
    ("How strange it is to be anything at all.", "Neutral Milk Hotel", """"In the Aeroplane Over the Sea""""),
    ("""Two-headed boy
<br>She is all you could need
<br>She will feed you tomatoes and radio wire
<br>And retire to sheets safe and clean
<br>But don't hate her when she gets up to leave.""", "Neutral Milk Hotel", """"Two Headed Boy Pt. II""""),
    ]

proc render(originalFile: string, replacements: varargs[(string, string)]): string =
    return originalFile.multiReplace(replacements)

proc sendTemplatedFile(settings: Settings, req: Request, route: seq[string], data: TemplateData, headers: HttpHeaders, isIndex: bool): HttpResponse =
    let url = route[0]

    if (req.url.query.len > 0) or (route.len > 1):
        return (code: Http301, content: "", headers: {"Location": "/" & url}.newHttpHeaders)

    let reqTime = cpuTime()

    data.canonicalLink = "<link rel=\"canonical\" href=\"http://bhm.sh/" & url & "\">"
    data.content = settings.files[url]

    var renderData = @[
        ("{{#pageTitle}}", "Brian's " & data.pageTitle),
        ("{{#canonicalLink}}", data.canonicalLink),
        ("{{#chyron}}", data.chyron),
    ]

    var contents: string
    if (isIndex):
        contents = render(data.content, @[
            ("{{#quoteText}}", data.quote.quote),
            ("{{#quoteAuthor}}", data.quote.author),
            ("{{#quoteCitation}}", data.quote.citation)
        ])
        renderData.add(("{{#content}}", contents))
    else:
        renderData.add(("{{#content}}", data.content))

    var rendered = render(mainTemplate, renderData)
    
    let 
        timeTaken = (cpuTime() - reqTime) * 1000
        finalContent = rendered.replace("{{#generationString}}", genString % $timeTaken.formatFloat(ffDecimal, 5))
    
    return (code: Http200, content: finalContent, headers: headers)

proc index(settings: Settings, req: Request, data: TemplateData, route: seq[string], headers: HttpHeaders): HttpResponse =
    let redirectResult = (code: Http301, content: "", headers: {"Location": "/"}.newHttpHeaders)
    if (req.url.query.len > 0) or (route.len > 1):
        return redirectResult

    return sendTemplatedFile(settings, req, @["index"], data, headers, true)

proc sendStaticFile(settings: Settings, req: Request): HttpResponse =
    let 
        url = req.url.path
        ext = url.splitFile.ext
        mimetype = settings.mimes.getMimetype(ext.toLowerAscii)
        file = settings.files[url[1 .. ^1]]

    return (code: Http200, content: file, headers: {"Content-Type": mimetype}.newHttpHeaders)

proc printReqInfo(settings: Settings, req: Request) =
    if settings.printLogging:
        echo getTime().local, " - ", req.hostname, " ", req.reqMethod, " ", req.url.path, " ", req.url.query

proc genMsg(settings: Settings): string =
    let url = "http://$1:$2/" % [settings.address, $settings.port.int]
    let t = now()
    let pid = getCurrentProcessId()
    result = """$1 v$2
Address:      $3 
Current Time: $4
PID:          $5""" % [settings.name, settings.version, url, $t, $pid]

proc logException(settings: Settings) =
    if not settings.printLogging:
        return

    let
        e = getCurrentException()
        msg = getCurrentExceptionMsg()
    echo repr(e), "\n", repr(msg)
    writeStackTrace()

proc serve*(settings: Settings) =
    var server = newAsyncHttpServer()
    echo genMsg(settings)

    proc handleRequest(req: Request): Future[void] {.async.} =
        var res: HttpResponse
        var data = TemplateData(pageTitle: sample(titles), chyron: sample(chyrons), quote: sample(quotes))
        let htmlContentHeader = {"Content-Type": "text/html"}.newHttpHeaders

        try:
            printReqInfo(settings, req)
            let route = toSeq(req.url.path.split("/"))[1 .. ^1] #always starts with `/`; discard first item

            if (route.len < 1) or (route[0] == "") or (route[0] == "index"):
                res = index(settings, req, data, route, htmlContentHeader)

            elif (route[0] in settings.files):
                res = sendTemplatedFile(settings, req, route, data, htmlContentHeader, false)

            elif (req.url.path[1 .. ^1] in settings.files):
                res = sendStaticFile(settings, req)

            else:
                res = sendTemplatedFile(settings, req, @["404"], data, htmlContentHeader, false)

        except:
            logException(settings)
            res = (code: Http500, content: "", headers: nil)
        await req.respond(res.code, res.content, res.headers)

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
        version: "0.2",
        files: files,
        domain: AF_INET,
        printLogging: true,
    )


    var addrInfo = getAddrInfo(settings.address, settings.port, settings.domain)
    if addrInfo == nil:
        echo "Error: Could not resolve address '" & settings.address & "'."
        quit(1)

    randomize()
    serve(settings)
    runForever()