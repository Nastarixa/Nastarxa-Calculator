NewCalculatorState() {
    return {
        tokens: [],
        current: "0",
        result: "",
        justEvaluated: false,
        error: ""
    }
}

CalculatorInputDigit(state, digit) {
    state.error := ""
    if (state.justEvaluated) {
        state.tokens := []
        state.current := digit
        state.result := ""
        state.justEvaluated := false
        return
    }

    if (state.current = "0")
        state.current := digit
    else
        state.current .= digit
}

CalculatorInputParen(state) {
    state.error := ""
    if (state.justEvaluated) {
        state.tokens := []
        state.current := "0"
        state.result := ""
        state.justEvaluated := false
    }

    if ShouldOpenParen(state) {
        if (state.current != "0" && state.current != "")
            state.tokens.Push(NormalizeNumberText(state.current))
        state.tokens.Push("(")
        state.current := "0"
        return
    }

    if (state.current != "" && state.current != "0") {
        state.tokens.Push(NormalizeNumberText(state.current))
        state.current := "0"
    }
    state.tokens.Push(")")
}

CalculatorInputPercent(state) {
    state.error := ""
    if (state.current = "" || state.current = "0")
        return

    state.current := FormatCalcNumber(Number(NormalizeNumberText(state.current)) / 100)
    state.justEvaluated := false
}

CalculatorInputDecimal(state) {
    state.error := ""
    if (state.justEvaluated) {
        state.tokens := []
        state.current := "0."
        state.result := ""
        state.justEvaluated := false
        return
    }

    if !InStr(state.current, ".")
        state.current .= "."
}

CalculatorInputOperator(state, op) {
    state.error := ""

    if (state.justEvaluated) {
        if (state.result != "") {
            state.tokens := [state.result, op]
            state.current := "0"
            state.justEvaluated := false
        }
        return
    }

    if (state.current != "" && !(state.current = "0" && state.tokens.Length > 0)) {
        state.tokens.Push(NormalizeNumberText(state.current))
        state.tokens.Push(op)
        state.current := "0"
        return
    }

    if (state.tokens.Length > 0 && IsOperatorToken(state.tokens[state.tokens.Length]))
        state.tokens[state.tokens.Length] := op
    else if (state.tokens.Length > 0 && state.tokens[state.tokens.Length] = ")")
        state.tokens.Push(op)
}

CalculatorEquals(state) {
    state.error := ""
    tokens := CalculatorExpressionTokens(state)
    if (tokens.Length = 0)
        return

    if (IsOperatorToken(tokens[tokens.Length]))
        tokens.RemoveAt(tokens.Length)

    if (tokens.Length = 0)
        return

    try {
        value := EvaluateExpressionTokens(tokens)
        state.tokens := tokens
        state.result := FormatCalcNumber(value)
        state.current := state.result
        state.justEvaluated := true
    } catch as err {
        state.error := err.Message
    }
}

CalculatorBackspace(state) {
    state.error := ""
    if (state.justEvaluated) {
        CalculatorClear(state)
        return
    }

    if (StrLen(state.current) <= 1 || (StrLen(state.current) = 2 && SubStr(state.current, 1, 1) = "-")) {
        state.current := "0"
        return
    }

    state.current := SubStr(state.current, 1, StrLen(state.current) - 1)
}

CalculatorClear(state) {
    state.tokens := []
    state.current := "0"
    state.result := ""
    state.justEvaluated := false
    state.error := ""
}

CalculatorToggleSign(state) {
    state.error := ""
    if (state.current = "0" || state.current = "")
        return

    if (SubStr(state.current, 1, 1) = "-")
        state.current := SubStr(state.current, 2)
    else
        state.current := "-" state.current
}

CalculatorDisplayValue(state) {
    if (state.error != "")
        return "Error"
    return state.current
}

CalculatorSetExpressionText(state, text) {
    text := Trim(text)
    if InStr(text, "=") {
        parts := StrSplit(text, "=")
        text := Trim(parts[1])
    }

    tokens := TokenizeExpressionText(text)
    if (tokens.Length = 0)
        throw Error("No expression found")

    state.tokens := []
    state.current := "0"
    state.result := ""
    state.justEvaluated := false
    state.error := ""

    last := tokens[tokens.Length]
    if !IsOperatorToken(last) && last != ")" && last != "(" {
        Loop tokens.Length - 1
            state.tokens.Push(tokens[A_Index])
        state.current := last
        return
    }

    for _, token in tokens
        state.tokens.Push(token)
}

TokenizeExpressionText(text) {
    text := StrReplace(text, "×", "*")
    text := StrReplace(text, "÷", "/")
    tokens := []
    pos := 1
    previousWasValue := false

    while (pos <= StrLen(text)) {
        ch := SubStr(text, pos, 1)
        if (ch = " " || ch = "`t") {
            pos += 1
            continue
        }

        if RegExMatch(SubStr(text, pos), "^-?\d+(?:\.\d+)?", &m) {
            if (SubStr(m[0], 1, 1) = "-" && previousWasValue)
                throw Error("Use an operator before a negative value")
            tokens.Push(m[0])
            pos += StrLen(m[0])
            previousWasValue := true
            continue
        }

        if InStr("+-*/()", ch) {
            tokens.Push(ch)
            previousWasValue := (ch = ")")
            pos += 1
            continue
        }

        throw Error("Unsupported character: " ch)
    }

    return tokens
}

CalculatorHistoryLine(state) {
    tokens := CalculatorExpressionTokens(state)
    if (tokens.Length = 0)
        return ""

    text := JoinExpressionTokens(tokens)
    if (state.justEvaluated && state.result != "")
        text .= " = " state.result
    return text
}

CalculatorExpressionTokens(state) {
    out := []
    for _, token in state.tokens
        out.Push(token)

    if (!state.justEvaluated && state.current != "" && (out.Length = 0 || IsOperatorToken(out[out.Length]))) {
        if !(state.current = "0" && out.Length > 0)
            out.Push(NormalizeNumberText(state.current))
    }

    return out
}

ShouldOpenParen(state) {
    tokens := CalculatorExpressionTokens(state)
    openCount := 0
    closeCount := 0
    for _, token in tokens {
        if (token = "(")
            openCount += 1
        else if (token = ")")
            closeCount += 1
    }

    if (tokens.Length = 0)
        return true
    last := tokens[tokens.Length]
    return IsOperatorToken(last) || last = "(" || openCount <= closeCount
}

JoinExpressionTokens(tokens) {
    text := ""
    for _, token in tokens {
        if (text = "")
            text := DisplayToken(token)
        else if IsOperatorToken(token)
            text .= " " DisplayToken(token) " "
        else if (token = ")")
            text .= ")"
        else if (token = "(")
            text .= "("
        else
            text .= DisplayToken(token)
    }
    return text
}

DisplayToken(token) {
    switch token {
        case "*":
            return "*"
        case "/":
            return "/"
        default:
            return token
    }
}

IsOperatorToken(token) {
    return token = "+" || token = "-" || token = "*" || token = "/"
}

NormalizeNumberText(text) {
    if (SubStr(text, -1) = ".")
        text := SubStr(text, 1, StrLen(text) - 1)
    if (text = "" || text = "-")
        return "0"
    return text
}

FormatCalcNumber(value) {
    rounded := Round(value, 10)
    if (Abs(rounded) < 0.0000000001)
        rounded := 0

    text := Format("{:.10f}", rounded)
    while (InStr(text, ".") && SubStr(text, -1) = "0")
        text := SubStr(text, 1, StrLen(text) - 1)
    if (SubStr(text, -1) = ".")
        text := SubStr(text, 1, StrLen(text) - 1)
    return text
}

RenderMathHistory(historyItems) {
    if (historyItems.Length = 0)
        return "No calculations yet."

    out := ""
    for _, item in historyItems
        out .= item "`r`n"
    return RTrim(out, "`r`n")
}
