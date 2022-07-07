# :computer: https://bhm.sh

This repository contains the code powering my personal website, https://bhm.sh.

The website is deployed as a single-file binary (written in [Nim!](https://nim-lang.org/)) managed by systemd, proxied by [NGINX](https://www.nginx.com), and using [Let's Encrypt](https://letsencrypt.org/) for SSL certificate management.

To serve the website, I wrote a webserver in Nim using [asynchttpserver](https://nim-lang.org/docs/asynchttpserver.html). The webserver core is responsible for identifying request destinations, assembling the correct content, and responding to the request (optionally gzipped!). For page requests, the webserver dynamically generates the resulting HTML using a simplistic token-based templating approach for HTML content.

The core of the webserver looks like this:

https://github.com/killerbat00/bhm.sh/blob/a9b05d861dccad2c8baf2be70331d94a700cd669/main.nim#L186-L225

All of the website's content and resources are compiled directly into the resulting binary so no files are read or written during normal operation (except for the log files, and stdout; this isn't really a pro, con, or anything other than a fun fact :relaxed:).

Feel free to build your own with any inspiration (or imitation) sparked by the code in this repository. It's lots of fun! One of my favorite parts of building a new personal website in this style has been adding my own touch, not only in code, but in fun dynamic elements like the page title and chyron (try refreshing the page a few times to see what I mean!).

This whole concept of a single-file binary website (and much of the structure and layout!) was inspired by Jes' version (https://j3s.sh/thought/my-website-is-one-binary.html) which was the first time I saw something similar.
