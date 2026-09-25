# First string-valued JSON field named by -v key=...; POSIX awk, LC_ALL=C.
# Scan strings, including escaped quotes, so string contents cannot become keys.
function hex4(s,    n,j,d) {
    if (length(s) != 4) exit 1
    n = 0
    for (j = 1; j <= 4; j++) {
        d = index("0123456789abcdef", tolower(substr(s,j,1))) - 1
        if (d < 0) exit 1
        n = n * 16 + d
    }
    return n
}
function utf8(n) {
    if (n == 0) exit 1
    if (n < 128) return sprintf("%c",n)
    if (n < 2048) return sprintf("%c%c",192+int(n/64),128+n%64)
    if (n < 65536) return sprintf("%c%c%c",224+int(n/4096),128+int(n/64)%64,128+n%64)
    return sprintf("%c%c%c%c",240+int(n/262144),128+int(n/4096)%64,128+int(n/64)%64,128+n%64)
}
function string(    out,c,n,low) {
    out = ""
    while (++i <= length(json)) {
        c = substr(json,i,1)
        if (c == "\"") return out
        if (c == "\\") {
            c = substr(json,++i,1)
            if (c == "u") {
                n = hex4(substr(json,i+1,4)); i += 4
                if (n >= 55296 && n <= 56319) {
                    if (substr(json,i+1,2) != "\\u") exit 1
                    low = hex4(substr(json,i+3,4)); i += 6
                    if (low < 56320 || low > 57343) exit 1
                    n = 65536 + (n-55296)*1024 + low-56320
                } else if (n >= 56320 && n <= 57343) exit 1
                c = utf8(n)
            } else if (c == "n") c = "\n"
            else if (c == "r") c = "\r"
            else if (c == "t") c = "\t"
            else if (c == "b") c = "\b"
            else if (c == "f") c = "\f"
            else if (c != "\"" && c != "\\" && c != "/") exit 1
        }
        out = out c
    }
    exit 1
}
{ json = json $0 "\n" }
END {
    for (i = 1; i <= length(json); i++) {
        if (substr(json,i,1) != "\"") continue
        token = string()
        rest = substr(json,i+1)
        if (token == key && match(rest,/^[[:space:]]*:[[:space:]]*"/)) {
            i += RLENGTH
            value = string()
            printf "%s", value
            exit
        }
    }
}
