EvaluateExpressionTokens(tokens) {
    values := []
    ops := []
    index := 1

    while (index <= tokens.Length) {
        token := tokens[index]
        if (token = "(") {
            ops.Push(token)
        } else if (token = ")") {
            while (ops.Length > 0 && ops[ops.Length] != "(")
                ApplyTopOperator(values, ops)
            if (ops.Length = 0)
                throw Error("Mismatched parentheses")
            ops.Pop()
        } else if IsOperatorToken(token) {
            while (ops.Length > 0 && ops[ops.Length] != "(" && OperatorPrecedence(ops[ops.Length]) >= OperatorPrecedence(token))
                ApplyTopOperator(values, ops)
            ops.Push(token)
        } else {
            values.Push(Number(token))
        }
        index += 1
    }

    while (ops.Length > 0) {
        if (ops[ops.Length] = "(")
            throw Error("Mismatched parentheses")
        ApplyTopOperator(values, ops)
    }

    if (values.Length != 1)
        throw Error("Incomplete expression")

    return values[1]
}

OperatorPrecedence(op) {
    if (op = "*" || op = "/")
        return 2
    return 1
}

ApplyTopOperator(values, ops) {
    if (values.Length < 2 || ops.Length < 1)
        throw Error("Incomplete expression")

    op := ops.Pop()
    right := values.Pop()
    left := values.Pop()

    switch op {
        case "+":
            values.Push(left + right)
        case "-":
            values.Push(left - right)
        case "*":
            values.Push(left * right)
        case "/":
            if (right = 0)
                throw Error("Cannot divide by zero")
            values.Push(left / right)
        default:
            throw Error("Unknown operator")
    }
}
