#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

if FileExist(A_ScriptDir "\Calculator.ico")
    TraySetIcon "Calculator.ico"

#Include "src/core/expression_eval.ahk"
#Include "src/core/calculator_state.ahk"
#Include "src/core/timer_laps.ahk"

global App := InitCalculatorApp()
BuildCalculatorGui(App)

Hotkey("F12", (*) => ToggleMainWindow(App))

HotIfWinActive("ahk_id " App.gui.Hwnd)
Hotkey("0", (*) => PressDigit(App, "0"))
Hotkey("1", (*) => PressDigit(App, "1"))
Hotkey("2", (*) => PressDigit(App, "2"))
Hotkey("3", (*) => PressDigit(App, "3"))
Hotkey("4", (*) => PressDigit(App, "4"))
Hotkey("5", (*) => PressDigit(App, "5"))
Hotkey("6", (*) => PressDigit(App, "6"))
Hotkey("7", (*) => PressDigit(App, "7"))
Hotkey("8", (*) => PressDigit(App, "8"))
Hotkey("9", (*) => PressDigit(App, "9"))
Hotkey(".", (*) => PressDecimal(App))
Hotkey("+", (*) => PressOperator(App, "+"))
Hotkey("-", (*) => PressOperator(App, "-"))
Hotkey("*", (*) => PressOperator(App, "*"))
Hotkey("/", (*) => PressOperator(App, "/"))
Hotkey("Enter", (*) => PressEquals(App))
Hotkey("Backspace", (*) => PressBackspace(App))
Hotkey("Esc", (*) => PressClear(App))
Hotkey("^z", (*) => UndoCalculator(App))
Hotkey("^+z", (*) => RedoCalculator(App))
Hotkey("^c", (*) => CopyCalculatorLine(App))
Hotkey("^t", (*) => TogglePin(App))
Hotkey("F1", (*) => ShowHelpWindow(App))
HotIfWinActive()

InitCalculatorApp() {
    return {
        state: NewCalculatorState(),
        gui: 0,
        controls: Map(),
        actionControls: Map(),
        hoverHwnd: 0,
        pressedHwnd: 0,
        lapText: "",
        lapRows: [],
        calcHistory: [],
        undoStack: [],
        redoStack: [],
        lapUndoStack: [],
        lapRedoStack: [],
        memoryValue: 0,
        memorySet: false,
        isPinned: false,
        historyGui: 0,
        lapsGui: 0,
        memoryGui: 0,
        helpGui: 0,
        storageDir: A_ScriptDir "\data",
        selectedHistoryItem: "",
        lastHistoryLine: "",
        recalledExpressionPreview: ""
    }
}

BuildCalculatorGui(app) {
    g := Gui("+Resize +MinSize344x570 +E0x10", "Nastarxa Calculator")
    g.BackColor := "000000"
    g.SetFont("s10", "Segoe UI")
    app.gui := g

    app.controls["history"] := g.AddText("x18 y18 w308 h24 Right c5E6A75 Background000000", "")
    app.controls["history"].OnEvent("Click", (*) => EditExpression(app))
    app.controls["display"] := g.AddText("x18 y54 w308 h62 Right cF8FAFC Background000000", "0")
    app.controls["display"].SetFont("s32 Bold", "Consolas")
    app.controls["display"].OnEvent("Click", (*) => EditExpression(app))
    app.controls["status"] := g.AddText("x18 y128 w308 h20 Right c6B7280 Background000000", "Drop timer data or image")

    LoadAppPersistence(app)

    app.controls["historyButton"] := AddActionText(g, "x18 y166 w42 h30", "H", "84CC16", "111315", "s12 Bold")
    app.controls["historyButton"].OnEvent("Click", (*) => ShowHistoryWindow(app))

    app.controls["lapsButton"] := AddActionText(g, "x70 y166 w42 h30", "L", "38BDF8", "111315", "s12 Bold")
    app.controls["lapsButton"].OnEvent("Click", (*) => HandleLapsButton(app))

    app.controls["undoButton"] := AddActionText(g, "x122 y166 w42 h30 0x200", "⤺", "FACC15", "111315", "s18")
    app.controls["undoButton"].SetFont("s17 Bold", "Consolas")
    app.controls["undoButton"].OnEvent("Click", (*) => UndoCalculator(app))

    app.controls["redoButton"] := AddActionText(g, "x174 y166 w42 h30 0x200", "⤻", "FACC15", "111315", "s18")
    app.controls["redoButton"].SetFont("s17 Bold", "Consolas")
    app.controls["redoButton"].OnEvent("Click", (*) => RedoCalculator(app))

    app.controls["memoryButton"] := AddActionText(g, "x226 y166 w32 h30", "M", "C084FC", "111315", "s12 Bold")
    app.controls["memoryButton"].OnEvent("Click", (*) => ShowMemoryWindow(app))

    app.controls["pinButton"] := AddActionText(g, "x268 y166 w58 h30", "Pin", "E0E7FF", "111315", "s9 Bold")
    app.controls["pinButton"].OnEvent("Click", (*) => TogglePin(app))

    app.controls["divider"] := g.AddText("x18 y212 w308 h1 Background202124", "")

    labels := [
        ["C", "()", "%", "/"],
        ["7", "8", "9", "*"],
        ["4", "5", "6", "-"],
        ["1", "2", "3", "+"],
        ["+/-", "0", ".", "="]
    ]

    y := 232
    for rowIndex, row in labels {
        x := 18
        for colIndex, label in row {
            colors := ButtonColors(label)
            btn := AddActionText(g, "x" x " y" y " w64 h54", label, colors.fg, colors.bg, "s18 Bold")
            btn.OnEvent("Click", BindCalculatorButton(app, label))
            app.controls["key_" rowIndex "_" colIndex] := btn
            x += 82
        }
        y += 66
    }

    g.OnEvent("Close", (*) => ExitApp())
    g.OnEvent("Size", (guiObj, minMax, width, height) => ResizeCalculator(app, width, height))
    g.OnEvent("DropFiles", (guiObj, guiCtrlObj, fileArray, x, y) => HandleDroppedFiles(app, fileArray))
    InitActionFeedback(app)
    ApplyPinnedState(app)
    RefreshCalculatorUi(app)
    OnExit((*) => PersistAppState(app))
    g.Show("w344 h584")
}

ToggleMainWindow(app) {
    if !IsObject(app.gui)
        return

    if WinExist("ahk_id " app.gui.Hwnd) && WinActive("ahk_id " app.gui.Hwnd) {
        app.gui.Hide()
        return
    }

    app.gui.Show()
    WinActivate("ahk_id " app.gui.Hwnd)
}

AddActionText(guiObj, pos, label, fg, bg, fontOptions) {
    ctrl := guiObj.AddText(pos " Center 0x200 Border c" fg " Background" bg, label)
    ctrl.SetFont(fontOptions, "Segoe UI")
    ctrl._normalFg := fg
    ctrl._normalBg := bg
    ctrl._hoverFg := LightenHex(fg, 35)
    ctrl._hoverBg := LightenHex(bg, 18)
    ctrl._pressFg := "FFFFFF"
    ctrl._pressBg := LightenHex(bg, 34)
    return ctrl
}

ButtonColors(label) {
    colors := { fg: "F8FAFC", bg: "151618" }
    if (label = "=")
        return { fg: "FFFFFF", bg: "2F9E13" }
    if IsOperatorButton(label)
        return { fg: "A3E635", bg: "1B2118" }
    if (label = "C")
        return { fg: "FF7A7A", bg: "241313" }
    if (label = "0")
        return { fg: "93C5FD", bg: "111827" }
    if (label = ".")
        return { fg: "CBD5E1", bg: "111315" }
    if (label = "+/-")
        return { fg: "CBD5E1", bg: "111315" }
    if (label = "()" || label = "%")
        return { fg: "A3E635", bg: "111315" }
    return colors
}

InitActionFeedback(app) {
    app.actionControls := Map()
    for _, ctrl in app.controls {
        if IsObject(ctrl) && ctrl.HasOwnProp("_normalBg")
            app.actionControls[ctrl.Hwnd] := ctrl
    }

    OnMessage(0x200, (wParam, lParam, msg, hwnd) => ActionMouseMove(app, hwnd))
    OnMessage(0x2A3, (wParam, lParam, msg, hwnd) => ActionMouseLeave(app, hwnd))
    OnMessage(0x201, (wParam, lParam, msg, hwnd) => ActionMouseDown(app, hwnd))
    OnMessage(0x202, (wParam, lParam, msg, hwnd) => ActionMouseUp(app, hwnd))
}

ActionMouseMove(app, hwnd) {
    if !app.actionControls.Has(hwnd) {
        ClearHoverControl(app)
        return
    }

    if (app.hoverHwnd != hwnd) {
        ClearHoverControl(app)
        app.hoverHwnd := hwnd
        ctrl := app.actionControls[hwnd]
        ApplyActionColors(ctrl, ctrl._hoverFg, ctrl._hoverBg)
        TrackMouseLeave(hwnd)
    }
}

ActionMouseLeave(app, hwnd) {
    if (app.hoverHwnd = hwnd)
        ClearHoverControl(app)
}

ActionMouseDown(app, hwnd) {
    if !app.actionControls.Has(hwnd)
        return

    app.pressedHwnd := hwnd
    ctrl := app.actionControls[hwnd]
    ApplyActionColors(ctrl, ctrl._pressFg, ctrl._pressBg)
}

ActionMouseUp(app, hwnd) {
    if (app.pressedHwnd = 0)
        return

    pressed := app.pressedHwnd
    app.pressedHwnd := 0

    if !app.actionControls.Has(pressed)
        return

    ctrl := app.actionControls[pressed]
    if (pressed = hwnd && app.hoverHwnd = hwnd)
        ApplyActionColors(ctrl, ctrl._hoverFg, ctrl._hoverBg)
    else
        ApplyActionColors(ctrl, ctrl._normalFg, ctrl._normalBg)
}

ClearHoverControl(app) {
    if (app.hoverHwnd = 0)
        return

    hwnd := app.hoverHwnd
    app.hoverHwnd := 0
    if app.actionControls.Has(hwnd) {
        ctrl := app.actionControls[hwnd]
        if (app.pressedHwnd != hwnd)
            ApplyActionColors(ctrl, ctrl._normalFg, ctrl._normalBg)
    }
}

ApplyActionColors(ctrl, fg, bg) {
    try ctrl.SetFont("c" fg)
    try ctrl.Opt("Background" bg)
    try ctrl.Redraw()
}

TrackMouseLeave(hwnd) {
    static TME_LEAVE := 0x00000002
    size := A_PtrSize = 8 ? 24 : 16
    tme := Buffer(size, 0)
    NumPut("UInt", size, tme, 0)
    NumPut("UInt", TME_LEAVE, tme, 4)
    NumPut("Ptr", hwnd, tme, 8)
    DllCall("TrackMouseEvent", "Ptr", tme)
}

LightenHex(hex, amount) {
    hex := StrReplace(hex, "#")
    r := Min(255, ("0x" SubStr(hex, 1, 2)) + amount)
    g := Min(255, ("0x" SubStr(hex, 3, 2)) + amount)
    b := Min(255, ("0x" SubStr(hex, 5, 2)) + amount)
    return Format("{:02X}{:02X}{:02X}", r, g, b)
}

ResizeCalculator(app, width, height) {
    if (width < 344 || height < 570)
        return

    rightW := width - 36
    app.controls["history"].Move(18, 18, rightW, 24)
    app.controls["display"].Move(18, 54, rightW, 62)
    app.controls["status"].Move(18, 128, rightW, 20)
    app.controls["historyButton"].Move(18, 166, 42, 30)
    app.controls["lapsButton"].Move(70, 166, 42, 30)
    app.controls["undoButton"].Move(122, 166, 42, 30)
    app.controls["redoButton"].Move(174, 166, 42, 30)
    app.controls["memoryButton"].Move(width - 118, 166, 32, 30)
    app.controls["pinButton"].Move(width - 76, 166, 58, 30)
    app.controls["divider"].Move(18, 212, rightW, 1)
}

BindCalculatorButton(app, label) {
    return (*) => HandleCalculatorButton(app, label)
}

HandleCalculatorButton(app, label) {
    switch label {
        case "C":
            PressClear(app)
        case "/":
            PressOperator(app, "/")
        case "*":
            PressOperator(app, "*")
        case "+", "-":
            PressOperator(app, label)
        case "=":
            PressEquals(app)
        case ".":
            PressDecimal(app)
        case "+/-":
            PressSignToggle(app)
        case "()":
            PressParen(app)
        case "%":
            PressPercent(app)
        default:
            PressDigit(app, label)
    }
}

IsOperatorButton(label) {
    return label = "+" || label = "-" || label = "*" || label = "/"
}

EditExpression(app) {
    current := CalculatorHistoryLine(app.state)
    if (current = "")
        current := CalculatorDisplayValue(app.state)

    result := InputBox("Edit expression:", "Expression Editing", "w420 h130", current)
    if (result.Result != "OK")
        return

    try {
        ClearRecallPreview(app)
        PushUndoSnapshot(app)
        CalculatorSetExpressionText(app.state, result.Value)
        RefreshCalculatorUi(app)
        app.controls["status"].Value := "Expression updated"
    } catch as err {
        app.controls["status"].Value := err.Message
    }
}

TogglePin(app) {
    app.isPinned := !app.isPinned
    ApplyPinnedState(app)
    PersistAppState(app)
    app.controls["status"].Value := app.isPinned ? "Always-on-top enabled" : "Always-on-top disabled"
}

ApplyPinnedState(app) {
    if !IsObject(app.gui)
        return
    app.gui.Opt(app.isPinned ? "+AlwaysOnTop" : "-AlwaysOnTop")
    if !app.controls.Has("pinButton")
        return
    pinBg := app.isPinned ? "1F2A44" : "111315"
    pinFg := app.isPinned ? "A7F3D0" : "E0E7FF"
    ctrl := app.controls["pinButton"]
    ctrl.Value := app.isPinned ? "Pinned" : "Pin"
    ctrl._normalBg := pinBg
    ctrl._normalFg := pinFg
    ctrl._hoverBg := LightenHex(pinBg, 18)
    ctrl._hoverFg := LightenHex(pinFg, 35)
    ApplyActionColors(ctrl, pinFg, pinBg)
}

PressDigit(app, digit) {
    ClearRecallPreview(app)
    PushUndoSnapshot(app)
    CalculatorInputDigit(app.state, digit)
    RefreshCalculatorUi(app)
}

PressDecimal(app) {
    ClearRecallPreview(app)
    PushUndoSnapshot(app)
    CalculatorInputDecimal(app.state)
    RefreshCalculatorUi(app)
}

PressOperator(app, op) {
    ClearRecallPreview(app)
    PushUndoSnapshot(app)
    CalculatorInputOperator(app.state, op)
    RefreshCalculatorUi(app)
}

PressEquals(app) {
    ClearRecallPreview(app)
    PushUndoSnapshot(app)
    CalculatorEquals(app.state)
    RecordMathHistory(app)
    RefreshCalculatorUi(app)
}

PressBackspace(app) {
    ClearRecallPreview(app)
    PushUndoSnapshot(app)
    CalculatorBackspace(app.state)
    RefreshCalculatorUi(app)
}

PressClear(app) {
    ClearRecallPreview(app)
    PushUndoSnapshot(app)
    CalculatorClear(app.state)
    RefreshCalculatorUi(app)
}

PressSignToggle(app) {
    ClearRecallPreview(app)
    PushUndoSnapshot(app)
    CalculatorToggleSign(app.state)
    RefreshCalculatorUi(app)
}

PressParen(app) {
    ClearRecallPreview(app)
    PushUndoSnapshot(app)
    CalculatorInputParen(app.state)
    RefreshCalculatorUi(app)
}

PressPercent(app) {
    ClearRecallPreview(app)
    PushUndoSnapshot(app)
    CalculatorInputPercent(app.state)
    RefreshCalculatorUi(app)
}

CopyCalculatorLine(app) {
    A_Clipboard := CalculatorHistoryLine(app.state)
    if (A_Clipboard = "")
        A_Clipboard := app.controls["display"].Value
    app.controls["status"].Value := "Copied"
}

ImportLapData(app) {
    file := FileSelect(1, A_ScriptDir, "Import timer lap data", "Timer data (*.txt; *.csv; *.tsv; *.log; *.png; *.jpg; *.jpeg; *.bmp)")
    if (file = "")
        return

    LoadLapFile(app, file)
}

HandleLapsButton(app) {
    if (app.lapRows.Length = 0) {
        ImportLapData(app)
        return
    }

    ShowLapsWindow(app)
}

ApplyLapData(app, raw) {
    app.lapText := raw
    app.lapRows := ParseTimerLaps(raw)
}

HandleDroppedFiles(app, fileArray) {
    if (fileArray.Length < 1)
        return

    LoadLapFile(app, fileArray[1])
}

LoadLapFile(app, file) {
    SplitPath(file, , , &ext)
    ext := StrLower(ext)

    try {
        if IsImageExtension(ext)
            raw := ReadTimerImageText(file)
        else
            raw := FileRead(file, "UTF-8")
    } catch as err {
        MsgBox("Could not read lap data.`n`n" err.Message, "Lap Import", "Iconx")
        return
    }

    PushLapUndoSnapshot(app)
    ApplyLapData(app, raw)
    PersistAppState(app)
    ShowLapsWindow(app)
    RefreshLapsWindow(app)

    if (app.lapRows.Length = 0 && IsImageExtension(ext))
        app.controls["status"].Value := "OCR ran, but no lap times were readable"
    else
        app.controls["status"].Value := "Loaded lap data: " app.lapRows.Length " row(s)"
}

IsImageExtension(ext) {
    return ext = "png" || ext = "jpg" || ext = "jpeg" || ext = "bmp"
}

ReadTimerImageText(file) {
    script := A_ScriptDir "\src\tools\ocr_timer_image.ps1"
    if !FileExist(script)
        throw Error("Missing OCR helper: " script)

    stamp := A_TickCount
    outFile := A_Temp "\nastarxa_calc_ocr_" stamp ".txt"
    errFile := A_Temp "\nastarxa_calc_ocr_" stamp ".err.txt"
    cmd := "powershell -NoProfile -ExecutionPolicy Bypass -File " QuoteArg(script) " " QuoteArg(file) " > " QuoteArg(outFile) " 2> " QuoteArg(errFile)
    exitCode := RunWait(A_ComSpec " /c " cmd, , "Hide")
    raw := FileExist(outFile) ? FileRead(outFile, "UTF-8") : ""
    err := FileExist(errFile) ? FileRead(errFile, "UTF-8") : ""
    try FileDelete(outFile)
    try FileDelete(errFile)

    if (exitCode != 0)
        throw Error(err != "" ? err : "Image OCR failed.")

    return raw
}

QuoteArg(value) {
    return '"' StrReplace(value, '"', '\"') '"'
}

LoadAppPersistence(app) {
    try DirCreate(app.storageDir)

    historyFile := app.storageDir "\calculator_history.txt"
    if FileExist(historyFile) {
        rawHistory := FileRead(historyFile, "UTF-8")
        for line in StrSplit(rawHistory, "`n", "`r") {
            line := Trim(line)
            if (line != "")
                app.calcHistory.Push(line)
        }
    }

    lapsFile := app.storageDir "\last_laps_raw.txt"
    if FileExist(lapsFile) {
        app.lapText := FileRead(lapsFile, "UTF-8")
        app.lapRows := ParseTimerLaps(app.lapText)
    }

    settingsFile := app.storageDir "\settings.ini"
    if FileExist(settingsFile) {
        app.memoryValue := Number(IniRead(settingsFile, "Memory", "Value", "0"))
        app.memorySet := IniRead(settingsFile, "Memory", "Set", "0") = "1"
        app.isPinned := IniRead(settingsFile, "Window", "Pinned", "0") = "1"
    }
}

PersistAppState(app) {
    try DirCreate(app.storageDir)

    historyFile := app.storageDir "\calculator_history.txt"
    historyText := ""
    for _, item in app.calcHistory
        historyText .= item "`r`n"
    try {
        if FileExist(historyFile)
            FileDelete(historyFile)
        FileAppend(historyText, historyFile, "UTF-8")
    }

    lapsFile := app.storageDir "\last_laps_raw.txt"
    try {
        if FileExist(lapsFile)
            FileDelete(lapsFile)
        if (app.lapText != "")
            FileAppend(app.lapText, lapsFile, "UTF-8")
    }

    settingsFile := app.storageDir "\settings.ini"
    try {
        IniWrite(FormatCalcNumber(app.memoryValue), settingsFile, "Memory", "Value")
        IniWrite(app.memorySet ? "1" : "0", settingsFile, "Memory", "Set")
        IniWrite(app.isPinned ? "1" : "0", settingsFile, "Window", "Pinned")
    }
}

PushUndoSnapshot(app) {
    snapshot := CloneCalculatorState(app.state)
    if (app.undoStack.Length > 0 && SerializeCalculatorState(app.undoStack[app.undoStack.Length]) = SerializeCalculatorState(snapshot))
        return
    app.undoStack.Push(snapshot)
    app.redoStack := []

    while (app.undoStack.Length > 80)
        app.undoStack.RemoveAt(1)
}

UndoCalculator(app) {
    if (app.undoStack.Length = 0) {
        if UndoLapImport(app)
            return
        app.controls["status"].Value := "Nothing to undo"
        return
    }

    app.redoStack.Push(CloneCalculatorState(app.state))
    app.state := app.undoStack.Pop()
    ClearRecallPreview(app)
    RefreshCalculatorUi(app)
    app.controls["status"].Value := "Undo"
}

RedoCalculator(app) {
    if (app.redoStack.Length = 0) {
        if RedoLapImport(app)
            return
        app.controls["status"].Value := "Nothing to redo"
        return
    }

    app.undoStack.Push(CloneCalculatorState(app.state))
    app.state := app.redoStack.Pop()
    ClearRecallPreview(app)
    RefreshCalculatorUi(app)
    app.controls["status"].Value := "Redo"
}

SerializeCalculatorState(state) {
    text := ""
    for _, token in state.tokens
        text .= token "|"
    return text "##" state.current "##" state.result "##" (state.justEvaluated ? "1" : "0") "##" state.error
}

PushLapUndoSnapshot(app) {
    app.lapUndoStack.Push({ text: app.lapText })
    app.lapRedoStack := []
    while (app.lapUndoStack.Length > 20)
        app.lapUndoStack.RemoveAt(1)
}

UndoLapImport(app) {
    if (app.lapUndoStack.Length = 0)
        return false
    app.lapRedoStack.Push({ text: app.lapText })
    snap := app.lapUndoStack.Pop()
    app.lapText := snap.text
    app.lapRows := app.lapText = "" ? [] : ParseTimerLaps(app.lapText)
    PersistAppState(app)
    RefreshLapsWindow(app)
    app.controls["status"].Value := "Undo lap import"
    return true
}

RedoLapImport(app) {
    if (app.lapRedoStack.Length = 0)
        return false
    app.lapUndoStack.Push({ text: app.lapText })
    snap := app.lapRedoStack.Pop()
    app.lapText := snap.text
    app.lapRows := app.lapText = "" ? [] : ParseTimerLaps(app.lapText)
    PersistAppState(app)
    RefreshLapsWindow(app)
    app.controls["status"].Value := "Redo lap import"
    return true
}

CloneCalculatorState(state) {
    tokens := []
    for _, token in state.tokens
        tokens.Push(token)

    return {
        tokens: tokens,
        current: state.current,
        result: state.result,
        justEvaluated: state.justEvaluated,
        error: state.error
    }
}

RecordMathHistory(app) {
    if (app.state.error != "" || !app.state.justEvaluated)
        return

    line := CalculatorHistoryLine(app.state)
    if (line = "" || line = app.lastHistoryLine)
        return

    app.calcHistory.InsertAt(1, line)
    app.lastHistoryLine := line

    while (app.calcHistory.Length > 30)
        app.calcHistory.Pop()

    PersistAppState(app)
}

RefreshCalculatorUi(app) {
    history := app.recalledExpressionPreview != "" ? app.recalledExpressionPreview : CalculatorHistoryLine(app.state)
    app.controls["history"].Value := history
    app.controls["display"].Value := CalculatorDisplayValue(app.state)
    if (app.state.error != "")
        app.controls["status"].Value := app.state.error
    else if (app.state.justEvaluated)
        app.controls["status"].Value := "Result saved to history"
    else
        app.controls["status"].Value := "Drop timer data or image anywhere"
}

ClearRecallPreview(app) {
    app.recalledExpressionPreview := ""
}

ShowHistoryWindow(app) {
    if IsObject(app.historyGui)
        try app.historyGui.Destroy()

    app.historyGui := Gui("+Owner" app.gui.Hwnd, "Calculation History")
    app.historyGui.BackColor := "101112"
    app.historyGui.SetFont("s10", "Segoe UI")
    app.historyGui.AddText("x16 y14 w300 h24 cA7D66D Background101112", "History")
    app.historyGui.AddText("x16 y38 w320 h18 c6B7280 Background101112", "Click an item to select it.")
    app.historyGui.controls := Map()
    app.historyGui.controls["rows"] := []

    y := 68
    if (app.calcHistory.Length = 0) {
        app.historyGui.AddText("x16 y" y " w320 h28 cCBD5E1 Background181A1D Center 0x200", "No calculations yet.")
    } else {
        maxRows := Min(12, app.calcHistory.Length)
        Loop maxRows {
            item := app.calcHistory[A_Index]
            rowBg := item = app.selectedHistoryItem ? "26331F" : "181A1D"
            row := app.historyGui.AddText("x16 y" y " w320 h26 cF8FAFC Background" rowBg " Border 0x200", "  " item)
            row.SetFont("s9", "Consolas")
            row._historyItem := item
            row.OnEvent("Click", BindHistorySelect(app, item, row))
            app.historyGui.controls["rows"].Push(row)
            y += 30
        }
    }

    copyBtn := app.historyGui.AddButton("x16 y380 w72 h32 cFFFFFF Background24272B", "Copy Sel")
    copyBtn.OnEvent("Click", (*) => CopySelectedHistory(app))
    loadBtn := app.historyGui.AddButton("x96 y380 w62 h32 cFFFFFF Background24272B", "Load")
    loadBtn.OnEvent("Click", (*) => RecallSelectedHistory(app))
    allBtn := app.historyGui.AddButton("x166 y380 w58 h32 cFFFFFF Background24272B", "Copy All")
    allBtn.OnEvent("Click", (*) => CopyHistory(app))
    clearBtn := app.historyGui.AddButton("x232 y380 w50 h32 cFFFFFF Background24272B", "Clear")
    clearBtn.OnEvent("Click", (*) => ClearHistoryWindow(app))
    closeBtn := app.historyGui.AddButton("x290 y380 w46 h32 cFFFFFF Background24272B", "Close")
    closeBtn.OnEvent("Click", (*) => app.historyGui.Hide())
    app.historyGui.controls["close"] := closeBtn
    app.historyGui.OnEvent("Close", (*) => app.historyGui.Hide())
    app.historyGui.Show("w352 h428")
    closeBtn.Focus()
}

BindHistorySelect(app, item, ctrl) {
    return (*) => SelectHistoryItem(app, item, ctrl)
}

SelectHistoryItem(app, item, ctrl) {
    app.selectedHistoryItem := item
    if IsObject(app.historyGui) && app.historyGui.controls.Has("rows") {
        for _, row in app.historyGui.controls["rows"] {
            bg := row._historyItem = item ? "26331F" : "181A1D"
            try row.Opt("Background" bg)
            try row.Redraw()
        }
    }
}

RecallSelectedHistory(app) {
    if (app.selectedHistoryItem = "" && app.calcHistory.Length > 0)
        app.selectedHistoryItem := app.calcHistory[1]
    RecallHistoryItem(app, app.selectedHistoryItem)
}

RecallHistoryItem(app, item) {
    item := Trim(item)
    if (item = "")
        return

    expression := item
    if InStr(expression, "=")
        expression := Trim(StrSplit(expression, "=")[1])
    if (expression = "")
        return

    PushUndoSnapshot(app)
    try {
        tokens := TokenizeExpressionText(expression)
        value := EvaluateExpressionTokens(tokens)
        app.state.tokens := []
        app.state.current := FormatCalcNumber(value)
        app.state.result := app.state.current
        app.state.justEvaluated := true
        app.state.error := ""
        app.recalledExpressionPreview := JoinExpressionTokens(tokens)
        RefreshCalculatorUi(app)
        app.controls["status"].Value := "Loaded history expression"
    } catch as err {
        app.controls["status"].Value := err.Message
    }
    try app.historyGui.Hide()
}

RefreshHistoryWindow(app) {
    if !IsObject(app.historyGui)
        return
    ShowHistoryWindow(app)
}

ClearHistoryWindow(app) {
    app.calcHistory := []
    app.lastHistoryLine := ""
    app.selectedHistoryItem := ""
    PersistAppState(app)
    RefreshHistoryWindow(app)
}

CopyHistory(app) {
    A_Clipboard := RenderMathHistory(app.calcHistory)
    if IsObject(app.historyGui)
        app.historyGui.Title := "Calculation History - copied"
}

CopySelectedHistory(app) {
    if (app.selectedHistoryItem = "" && app.calcHistory.Length > 0)
        app.selectedHistoryItem := app.calcHistory[1]
    A_Clipboard := app.selectedHistoryItem
    if IsObject(app.historyGui)
        app.historyGui.Title := "Calculation History - selected copied"
}

ShowMemoryWindow(app) {
    if IsObject(app.memoryGui)
        try app.memoryGui.Destroy()

    app.memoryGui := Gui("+Owner" app.gui.Hwnd, "Memory")
    app.memoryGui.BackColor := "101112"
    app.memoryGui.SetFont("s10", "Segoe UI")
    app.memoryGui.controls := Map()
    app.memoryGui.AddText("x16 y14 w250 h24 cC084FC Background101112", "Memory")
    value := app.memorySet ? FormatCalcNumber(app.memoryValue) : "Empty"
    app.memoryGui.controls["value"] := app.memoryGui.AddText("x16 y44 w250 h30 cFFFFFF Background181A1D Center 0x200", value)

    labels := ["MC", "MR", "M+", "M-", "MS"]
    x := 16
    for _, label in labels {
        btn := app.memoryGui.AddButton("x" x " y90 w48 h32 cFFFFFF Background24272B", label)
        btn.OnEvent("Click", BindMemoryAction(app, label))
        x += 52
    }

    closeBtn := app.memoryGui.AddButton("x176 y140 w90 h32 cFFFFFF Background24272B", "Close")
    closeBtn.OnEvent("Click", (*) => app.memoryGui.Hide())
    app.memoryGui.controls["close"] := closeBtn
    app.memoryGui.OnEvent("Close", (*) => app.memoryGui.Hide())
    app.memoryGui.Show("w282 h188")
    closeBtn.Focus()
}

BindMemoryAction(app, label) {
    return (*) => HandleMemoryAction(app, label)
}

HandleMemoryAction(app, label) {
    try value := Number(CalculatorDisplayValue(app.state))
    catch {
        app.controls["status"].Value := "Memory needs a numeric display"
        return
    }

    switch label {
        case "MC":
            app.memoryValue := 0
            app.memorySet := false
        case "MR":
            if app.memorySet {
                ClearRecallPreview(app)
                PushUndoSnapshot(app)
                app.state.tokens := []
                app.state.current := FormatCalcNumber(app.memoryValue)
                app.state.result := ""
                app.state.justEvaluated := false
                app.state.error := ""
                RefreshCalculatorUi(app)
            }
        case "MS":
            app.memoryValue := value
            app.memorySet := true
        case "M+":
            app.memoryValue += value
            app.memorySet := true
        case "M-":
            app.memoryValue -= value
            app.memorySet := true
    }

    PersistAppState(app)
    if IsObject(app.memoryGui)
        app.memoryGui.controls["value"].Value := app.memorySet ? FormatCalcNumber(app.memoryValue) : "Empty"
}

ShowLapsWindow(app) {
    if !IsObject(app.lapsGui) {
        app.lapsGui := Gui("+Owner" app.gui.Hwnd " +E0x10", "Timer Laps")
        app.lapsGui.BackColor := "101112"
        app.lapsGui.SetFont("s10", "Segoe UI")
        app.lapsGui.AddText("x16 y14 w300 h24 cA7D66D Background101112", "Laps")
        app.lapsGui.controls := Map()
        app.lapsGui.controls["summary"] := app.lapsGui.AddEdit("x16 y42 w380 h86 cDDE7C7 Background181A1D -Wrap ReadOnly", "")
        app.lapsGui.controls["list"] := app.lapsGui.AddEdit("x16 y138 w380 h258 cFFFFFF Background181A1D -Wrap ReadOnly", "")
        copyBtn := app.lapsGui.AddButton("x16 y420 w64 h32 cFFFFFF Background24272B", "Copy")
        copyBtn.OnEvent("Click", (*) => CopyLaps(app))
        txtBtn := app.lapsGui.AddButton("x86 y420 w64 h32 cFFFFFF Background24272B", "TXT")
        txtBtn.OnEvent("Click", (*) => ExportLapsText(app))
        pngBtn := app.lapsGui.AddButton("x156 y420 w64 h32 cFFFFFF Background24272B", "PNG")
        pngBtn.OnEvent("Click", (*) => ExportLapsPng(app))
        importBtn := app.lapsGui.AddButton("x226 y420 w74 h32 cFFFFFF Background24272B", "Import")
        importBtn.OnEvent("Click", (*) => ImportLapData(app))
        closeBtn := app.lapsGui.AddButton("x306 y420 w90 h32 cFFFFFF Background24272B", "Close")
        closeBtn.OnEvent("Click", (*) => app.lapsGui.Hide())
        app.lapsGui.controls["close"] := closeBtn
        app.lapsGui.OnEvent("DropFiles", (guiObj, guiCtrlObj, fileArray, x, y) => HandleDroppedFiles(app, fileArray))
        app.lapsGui.OnEvent("Close", (*) => app.lapsGui.Hide())
    }
    RefreshLapsWindow(app)
    app.lapsGui.Show("w412 h468")
    app.lapsGui.controls["close"].Focus()
}

RefreshLapsWindow(app) {
    if !IsObject(app.lapsGui)
        return
    app.lapsGui.controls["summary"].Value := RenderLapSummary(app.lapRows)
    app.lapsGui.controls["list"].Value := RenderLapDifferences(app.lapRows)
}

CopyLaps(app) {
    A_Clipboard := RenderLapSummary(app.lapRows) "`r`n`r`n" RenderLapDifferences(app.lapRows)
    if IsObject(app.lapsGui)
        app.lapsGui.Title := "Timer Laps - copied"
}

BuildLapExportText(app) {
    stats := BuildLapExportStats(app.lapRows)
    total := app.lapRows.Length > 0 ? FormatDurationForExport(app.lapRows[app.lapRows.Length].elapsedMs) : "00:00:00"
    text := "File: Nastarxa Calculator Export`r`n"
    text .= "Work Time: " total "`r`n"
    text .= "Total Laps: " stats.totalLaps "`r`n"
    text .= "Fastest: " stats.fastestText "`r`n"
    text .= "Slowest: " stats.slowestText "`r`n"
    text .= "Average: " stats.averageText "`r`n"
    text .= "Laps:`r`n"
    for _, row in app.lapRows {
        diff := row.diffMs = "" ? "--" : FormatSignedDurationForExport(row.diffMs)
        text .= "  " row.name "  " FormatDurationForExport(row.elapsedMs) "  d " diff "`r`n"
    }
    text .= "------------------`r`n"
    text .= "Day: " FormatTime(, "dddd") "`r`n"
    text .= "Save Time: " FormatTime(, "HH:mm:ss") "`r`n"
    text .= "Date: " FormatTime(, "yyyy-MM-dd") "`r`n"
    return text
}

BuildLapExportStats(rows) {
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

    averageText := diffCount > 0 ? FormatDurationForExport(Round(totalDiff / diffCount)) : "--"
    fastestText := IsObject(fastest) ? fastest.name " d " FormatSignedDurationForExport(fastest.diffMs) : "--"
    slowestText := IsObject(slowest) ? slowest.name " d " FormatSignedDurationForExport(slowest.diffMs) : "--"

    return {
        totalLaps: rows.Length,
        fastestText: fastestText,
        slowestText: slowestText,
        averageText: averageText
    }
}

FormatDurationForExport(ms) {
    totalSeconds := Floor(Abs(ms) / 1000)
    seconds := Mod(totalSeconds, 60)
    minutes := Mod(Floor(totalSeconds / 60), 60)
    hours := Floor(totalSeconds / 3600)
    return Format("{:02}:{:02}:{:02}", hours, minutes, seconds)
}

FormatSignedDurationForExport(ms) {
    if (ms = "")
        return "--"
    sign := ms >= 0 ? "+" : "-"
    return sign FormatDurationForExport(ms)
}

ExportLapsText(app) {
    if (app.lapRows.Length = 0) {
        app.controls["status"].Value := "No lap data to export"
        return
    }

    path := FileSelect("S16", DefaultExportPath("laps", "txt"), "Export Laps Text", "Text (*.txt)")
    if (path = "")
        return
    if !RegExMatch(path, "i)\.txt$")
        path .= ".txt"

    try {
        if FileExist(path)
            FileDelete(path)
        FileAppend(BuildLapExportText(app), path, "UTF-8")
        app.controls["status"].Value := "Exported laps text"
    } catch as err {
        MsgBox("Could not export text.`n`n" err.Message, "Export Laps", "Iconx")
    }
}

ExportLapsPng(app) {
    if (app.lapRows.Length = 0) {
        app.controls["status"].Value := "No lap data to export"
        return
    }

    path := FileSelect("S16", DefaultExportPath("laps", "png"), "Export Laps PNG", "PNG (*.png)")
    if (path = "")
        return
    if !RegExMatch(path, "i)\.png$")
        path .= ".png"

    tempText := A_Temp "\nastarxa_laps_export_" A_TickCount ".txt"
    script := A_ScriptDir "\src\tools\render_laps_png.ps1"
    try {
        if FileExist(tempText)
            FileDelete(tempText)
        FileAppend(BuildLapExportText(app), tempText, "UTF-8")
        exitCode := RunWait(A_ComSpec " /c powershell -NoProfile -ExecutionPolicy Bypass -File " QuoteArg(script) " " QuoteArg(tempText) " " QuoteArg(path), , "Hide")
        if (exitCode != 0)
            throw Error("PNG renderer failed.")
        app.controls["status"].Value := "Exported laps PNG"
    } catch as err {
        MsgBox("Could not export PNG.`n`n" err.Message, "Export Laps", "Iconx")
    } finally {
        try FileDelete(tempText)
    }
}

DefaultExportPath(prefix, extension) {
    folder := A_MyDocuments
    if (folder = "")
        folder := A_ScriptDir
    try DirCreate(folder)

    stamp := FormatTime(, "yyyy-MM-dd_HH-mm-ss")
    baseName := prefix "_" stamp
    candidate := folder "\" baseName "." extension
    if !FileExist(candidate)
        return candidate

    Loop 99 {
        candidate := folder "\" baseName "_" Format("{:02}", A_Index) "." extension
        if !FileExist(candidate)
            return candidate
    }

    return folder "\" baseName "_" A_TickCount "." extension
}

ShowHelpWindow(app) {
    if IsObject(app.helpGui) {
        try app.helpGui.Show()
        try app.helpGui.controls["close"].Focus()
        return
    }

    app.helpGui := Gui("+Owner" app.gui.Hwnd, "Calculator Help")
    app.helpGui.BackColor := "101112"
    app.helpGui.SetFont("s10", "Segoe UI")
    app.helpGui.AddText("x16 y14 w300 h24 cA7D66D Background101112", "Shortcuts and Features")
    helpText := ""
        . "Keyboard`r`n"
        . "0-9, ., +, -, *, /  Input numbers/operators`r`n"
        . "Enter              Equals`r`n"
        . "Backspace          Delete digit`r`n"
        . "Esc                Clear`r`n"
        . "Ctrl+Z             Undo`r`n"
        . "Ctrl+Shift+Z       Redo`r`n"
        . "Ctrl+T             Pin always-on-top`r`n"
        . "Ctrl+C             Copy current line`r`n"
        . "F1                 Help`r`n`r`n"
        . "Buttons`r`n"
        . "H                  Open calculation history`r`n"
        . "L                  Open/import timer laps`r`n"
        . "⤺ / ⤻              Undo / Redo`r`n"
        . "M                  Memory buttons: MC, MR, M+, M-, MS`r`n"
        . "Pin                Toggle always-on-top`r`n`r`n"
        . "Editing`r`n"
        . "Click the display or expression history to edit the expression.`r`n"
        . "History rows select first, then Copy Sel or Load.`r`n`r`n"
        . "Timer Data`r`n"
        . "Drag .txt/.png/.jpg timer data onto the calculator or Laps window.`r`n"
        . "Laps can export TXT or a PNG styled like the timer example.`r`n"
        . "The app saves history, memory, pin state, and the last lap import in data\."
    app.helpGui.AddEdit("x16 y46 w380 h300 cFFFFFF Background181A1D -Wrap ReadOnly", helpText)
    closeBtn := app.helpGui.AddButton("x306 y360 w90 h32 cFFFFFF Background24272B", "Close")
    closeBtn.OnEvent("Click", (*) => app.helpGui.Hide())
    app.helpGui.controls := Map()
    app.helpGui.controls["close"] := closeBtn
    app.helpGui.OnEvent("Close", (*) => app.helpGui.Hide())
    app.helpGui.Show("w412 h408")
    closeBtn.Focus()
}
