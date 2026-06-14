ParseTimerLaps(raw) {
    rows := []
    lines := StrSplit(raw, "`n", "`r")
    lapStart := 1
    lapEnd := lines.Length
    foundLapSection := false

    for idx, rawLine in lines {
        line := Trim(rawLine)
        if RegExMatch(line, "i)^laps:?\s*$") {
            lapStart := idx + 1
            foundLapSection := true
            break
        }
    }

    if (foundLapSection) {
        idx := lapStart
        while (idx <= lines.Length) {
            line := Trim(lines[idx])
            if (line = "" || RegExMatch(line, "^-+$") || RegExMatch(line, "i)^(file|work|day|save time|date)\b"))
                break
            idx += 1
        }
        lapEnd := idx - 1
    }

    pendingTimeText := ""
    pendingTimeMs := ""
    idx := lapStart
    while (idx <= lapEnd) {
        lineNo := idx
        line := Trim(lines[idx])
        if (line = "") {
            idx += 1
            continue
        }

        if !TryExtractLapTime(line, &timeText, &ms) {
            if (pendingTimeText != "" && IsLikelyLapName(line)) {
                AddLapRow(rows, lineNo, line, pendingTimeText, pendingTimeMs)
                pendingTimeText := ""
                pendingTimeMs := ""
            }
            idx += 1
            continue
        }

        name := Trim(SubStr(line, 1, InStr(line, timeText) - 1))
        name := Trim(name, " ,;|-`t")
        if (name = "" || IsLikelyOcrTimeFragment(name)) {
            pendingTimeText := timeText
            pendingTimeMs := ms
        } else {
            AddLapRow(rows, lineNo, name, timeText, ms)
            pendingTimeText := ""
            pendingTimeMs := ""
        }
        idx += 1
    }

    return rows
}

TryExtractLapTime(line, &timeText, &ms) {
    ; Reads the last time-like cell, so lap names can change while row layout stays stable.
    pattern := "i)([0-9eiool]{1,2}:)?[0-9eiool]{1,2}\s*:\s*[0-9eiool]{2}(?:[.,]\d{1,3})?|\d+(?:[.,]\d{1,3})?\s*(?:ms|s|sec|secs|second|seconds|min|minute|minutes)"
    pos := 1
    found := ""

    while RegExMatch(line, pattern, &m, pos) {
        found := m[0]
        pos := m.Pos + m.Len
    }

    if (found = "")
        return false

    timeText := NormalizeOcrDurationText(found)
    ms := ParseDurationMs(timeText)
    return true
}

AddLapRow(rows, lineNo, name, timeText, ms) {
    name := Trim(name, " ,;|-`t")
    if (name = "" || RegExMatch(name, "^[^\w]+$"))
        name := "Lap " rows.Length + 1

    prevMs := rows.Length > 0 ? rows[rows.Length].elapsedMs : ""
    diffMs := (prevMs = "") ? "" : ms - prevMs

    rows.Push({
        index: rows.Length + 1,
        sourceLine: lineNo,
        name: NormalizeOcrLapName(name),
        timeText: timeText,
        elapsedMs: ms,
        diffMs: diffMs
    })
}

IsLikelyLapName(line) {
    if (line = "")
        return false
    if RegExMatch(line, "i)^(file|work|laps|day|save time|date)\b")
        return false
    if RegExMatch(line, "^-+$")
        return false
    return true
}

IsLikelyOcrTimeFragment(text) {
    text := Trim(text)
    if (text = "")
        return true
    normalized := NormalizeOcrDurationText(text)
    return RegExMatch(normalized, "^[0-9:.,]+$")
}

NormalizeOcrLapName(name) {
    name := Trim(name)
    name := RegExReplace(name, "i)\bLap\s+I\b", "Lap 1")
    name := RegExReplace(name, "i)\bLap\s+IO\b", "Lap 10")
    return name
}

NormalizeOcrDurationText(text) {
    text := StrLower(text)
    text := StrReplace(text, " ", "")
    text := StrReplace(text, "•", "")
    text := StrReplace(text, "e", "0")
    text := StrReplace(text, "o", "0")
    text := StrReplace(text, "i", "1")
    text := StrReplace(text, "l", "1")
    text := RegExReplace(text, "[^0-9:.,a-z]", "")
    return text
}

ParseDurationMs(text) {
    t := Trim(StrLower(StrReplace(text, ",", ".")))

    if RegExMatch(t, "^(?:(\d{1,2}):)?(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?$", &m) {
        hours := (m[1] = "") ? 0 : Number(m[1])
        minutes := Number(m[2])
        seconds := Number(m[3])
        millis := PadMillis(m[4])
        return Round(((hours * 3600) + (minutes * 60) + seconds) * 1000 + millis)
    }

    if RegExMatch(t, "^(\d+(?:\.\d+)?)\s*(ms|s|sec|secs|second|seconds|min|minute|minutes)$", &m) {
        value := Number(m[1])
        unit := m[2]
        if (unit = "ms")
            return Round(value)
        if (unit = "min" || unit = "minute" || unit = "minutes")
            return Round(value * 60000)
        return Round(value * 1000)
    }

    throw Error("Unsupported time value: " text)
}

PadMillis(text) {
    if (text = "")
        return 0
    while (StrLen(text) < 3)
        text .= "0"
    if (StrLen(text) > 3)
        text := SubStr(text, 1, 3)
    return Number(text)
}

RenderLapDifferences(rows) {
    if (rows.Length = 0)
        return "No lap rows found."

    out := ""
    for _, row in rows {
        diff := row.diffMs = "" ? "--" : FormatSignedDuration(row.diffMs)
        out .= Format("{:02}. {} | {} | d {}`r`n", row.index, row.name, FormatDuration(row.elapsedMs), diff)
    }
    return RTrim(out, "`r`n")
}

RenderLapSummary(rows) {
    if (rows.Length = 0)
        return "No lap data loaded."

    fastest := ""
    slowest := ""
    totalDiff := 0
    diffCount := 0

    for _, row in rows {
        if (row.diffMs = "")
            continue
        if (fastest = "" || row.diffMs < fastest.diffMs)
            fastest := row
        if (slowest = "" || row.diffMs > slowest.diffMs)
            slowest := row
        totalDiff += row.diffMs
        diffCount += 1
    }

    avg := diffCount > 0 ? FormatDuration(Round(totalDiff / diffCount)) : "--"
    fastestText := IsObject(fastest) ? fastest.name " " FormatDuration(fastest.diffMs) : "--"
    slowestText := IsObject(slowest) ? slowest.name " " FormatDuration(slowest.diffMs) : "--"
    totalText := FormatDuration(rows[rows.Length].elapsedMs)

    return "Rows: " rows.Length
        . " | Total: " totalText
        . "`r`nFastest: " fastestText
        . "`r`nSlowest: " slowestText
        . "`r`nAverage: " avg
}

FormatDuration(ms) {
    sign := ms < 0 ? "-" : ""
    ms := Abs(ms)
    totalSeconds := Floor(ms / 1000)
    millis := Mod(ms, 1000)
    seconds := Mod(totalSeconds, 60)
    minutes := Mod(Floor(totalSeconds / 60), 60)
    hours := Floor(totalSeconds / 3600)

    if (hours > 0)
        return Format("{}{}:{:02}:{:02}.{:03}", sign, hours, minutes, seconds, millis)
    return Format("{}{}:{:02}.{:03}", sign, minutes, seconds, millis)
}

FormatSignedDuration(ms) {
    if (ms = 0)
        return "+0:00.000"
    sign := ms > 0 ? "+" : "-"
    return sign FormatDuration(Abs(ms))
}
