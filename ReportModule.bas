'******************************************
' 函数: GetFileNamesFromTable
' 用途: 从文件信息表中获取指定序号的文件名和报告标题
' 参数: 
'   - ws: 工作表对象
'   - reportIndex: 报告序号
' 返回: Collection对象，包含所有文件名和报告标题
'******************************************
Private Function GetFileNamesFromTable(ByVal ws As Worksheet, ByVal reportIndex As Long) As Collection
    Dim fileNames As New Collection
    
    '获取文件信息表对象
    Dim filesTable As ListObject
    Set filesTable = GetListObjectByName(ws, "文件信息表")
    
    If filesTable Is Nothing Then
        Err.Raise 1000, "GetFileNamesFromTable", "未找到文件信息表！"
    End If
    
    '根据序号获取对应行的数据
    With filesTable.ListRows(reportIndex)
        fileNames.Add .Range.Cells(1, filesTable.ListColumns("输入循环数据的文件名").Index).Value, "cyclesData"
        fileNames.Add .Range.Cells(1, filesTable.ListColumns("输入中检容量数据的文件名").Index).Value, "zp"
        fileNames.Add .Range.Cells(1, filesTable.ListColumns("输入中检DCR数据的文件名").Index).Value, "zpDCR"
        fileNames.Add .Range.Cells(1, filesTable.ListColumns("输出的测试报告标题").Index).Value, "reportTitle"
    End With
    
    Set GetFileNamesFromTable = fileNames
End Function

'******************************************
' 函数: GetRawDataFromFiles
' 用途: 从文件中获取原始数据
' 参数: 
'   - fileNames: 包含所有文件名的Collection对象
' 返回: Collection对象，包含所有原始数据
'******************************************
Private Function GetRawDataFromFiles(ByVal fileNames As Collection) As Collection
    Dim rawData As New Collection
    Dim ws As Worksheet
    Dim wb As Workbook
    
    '获取循环数据
    Set ws = GetWorksheetFromFile(fileNames("cyclesData"), "工步数据")
    If ws Is Nothing Then
        Err.Raise 1001, "GetRawDataFromFiles", "无法打开循环数据文件：" & fileNames("cyclesData")
    End If
    rawData.Add ExtractCycleDataFromWorksheet(ws), "cyclesData"
    Set wb = ws.Parent
    If Not wb Is ThisWorkbook Then
        wb.Close SaveChanges:=False
    End If
    
    '获取中检容量数据
    Set ws = GetWorksheetFromFile(fileNames("zp"), "工步数据")
    If ws Is Nothing Then
        Err.Raise 1001, "GetRawDataFromFiles", "无法打开中检容量数据文件：" & fileNames("zp")
    End If
    rawData.Add ExtractCycleDataFromWorksheet(ws), "zpData"
    Set wb = ws.Parent
    If Not wb Is ThisWorkbook Then
        wb.Close SaveChanges:=False
    End If
    
    '获取中检DCR数据
    Set ws = GetWorksheetFromFile(fileNames("zpDCR"), "详细数据")
    If ws Is Nothing Then
        Err.Raise 1001, "GetRawDataFromFiles", "无法打开中检DCR数据文件：" & fileNames("zpDCR")
    End If
    rawData.Add ExtractZPDCRDataFromWorksheet(ws), "zpDCRData"
    Set wb = ws.Parent
    If Not wb Is ThisWorkbook Then
        wb.Close SaveChanges:=False
    End If
    
    Set GetRawDataFromFiles = rawData
End Function

'******************************************
' 过程: GenerateReport
' 用途: 响应"输出报告"按钮点击，生成相关报告
' 参数: 无
'******************************************
Public Sub GenerateReport()
    On Error GoTo ErrorHandler
    
    '获取当前工作表
    Dim ws As Worksheet
    Set ws = ThisWorkbook.ActiveSheet
    
    '获取报告的序号
    Dim reportIndex As Variant
    reportIndex = ws.Cells(3, 9).Value
    
    '获取文件名集合
    Dim fileNames As Collection
    Set fileNames = GetFileNamesFromTable(ws, reportIndex)
    
    '获取原始数据
    Dim rawData As Collection
    Set rawData = GetRawDataFromFiles(fileNames)
    
    '获取循环配置
    Dim cycleConfig As Collection
    Set cycleConfig = ReadCycleConfig(reportIndex)

    '获取公共配置
    Dim commonConfig As Collection
    Set commonConfig = ReadCommonConfig()
    '获取报告名称
    Dim reportName As String
    reportName = fileNames(fileNames.Count)
    
    '输出报告
    If OutputReport(reportIndex, reportName, rawData, cycleConfig, commonConfig) Then
        MsgBox "报告生成完成！", vbInformation, "成功"
    End If
    Exit Sub
    
ErrorHandler:
    MsgBox "生成报告时发生错误：" & vbNewLine & Err.Description, vbCritical, "错误"
End Sub

'******************************************
' 函数: OutputReport
' 用途: 输出测试报告到新的工作表
' 参数: reportIndex - 报告序号
'       reportName - 报告名称
'       rawData - 原始数据集合
'       cycleConfig - 循环配置集合
'       commonConfig - 公共配置集合
'******************************************
Private Function OutputReport(ByVal reportIndex As Long, _
                            ByVal reportName As String, _
                            ByVal rawData As Collection, _
                            ByVal cycleConfig As Collection, _
                            ByVal commonConfig As Collection) As Boolean
    
    On Error GoTo ErrorHandler
    
    '保存当前引用样式
    Dim originalStyle As Boolean
    originalStyle = Application.ReferenceStyle
    
    '设置为R1C1引用样式
    If Application.ReferenceStyle <> xlR1C1 Then
        Application.ReferenceStyle = xlR1C1
    End If
    
    '获取当前工作簿
    Dim wb As Workbook
    Set wb = ThisWorkbook
    
    '检查工作表是否已存在
    Dim wsName As String
    Dim ws As Worksheet
    wsName = reportName
    
    On Error Resume Next
    Set ws = wb.Worksheets(wsName)
    On Error GoTo 0
    
    If ws Is Nothing Then
        '如果工作表不存在，创建新工作表
        Set ws = wb.Worksheets.Add(After:=wb.Sheets(wb.Sheets.Count))
        ws.Name = wsName
    Else
        '如果工作表已存在，清空内容
        ws.Cells.Clear
    End If
    
    '设置工作表样式和内容
    Dim nextRow As Long
    nextRow = SetupWorksheetStyle(ws, commonConfig, reportName)
    
    '添加循环数据
    nextRow = OutputCycleData(ws, rawData, cycleConfig, commonConfig)
    
    '设置函数返回值为成功
    OutputReport = True
    
    '激活工作表
    ws.Activate
    
    '定位到第一行第一列,方便用户查看报告开头
    ws.Cells(1, 1).Select
    
    '恢复原始引用样式
    If originalStyle <> Application.ReferenceStyle Then
        Application.ReferenceStyle = originalStyle
    End If
    
    '正常退出函数
    Exit Function
    
ErrorHandler:
    '确保在出错时也恢复引用样式
    If originalStyle <> Application.ReferenceStyle Then
        Application.ReferenceStyle = originalStyle
    End If
    
    OutputReport = False
    MsgBox "输出报告时发生错误：" & vbNewLine & Err.Description, vbCritical, "错误"
End Function

'******************************************
' 函数: SheetExists
' 用途: 检查指定名称的工作表是否存在
' 参数: sheetName - 工作表名称
'******************************************
Private Function SheetExists(ByVal sheetName As String) As Boolean
    Dim ws As Worksheet
    
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets(sheetName)
    On Error GoTo 0
    
    SheetExists = Not ws Is Nothing
End Function

'******************************************
' 函数: SetupWorksheetStyle
' 用途: 设置工作表样式，包括标题、表格等
' 返回: 最后一行的下一行的行号
'******************************************
Private Function SetupWorksheetStyle(ByVal ws As Worksheet, ByVal commonConfig As Collection, ByVal reportName As String) As Long
    '保存当前引用样式
    Dim originalStyle As Boolean
    originalStyle = Application.ReferenceStyle
    
    '设置为R1C1引用样式
    If Application.ReferenceStyle <> xlR1C1 Then
        Application.ReferenceStyle = xlR1C1
    End If
    
    '初始化工作表
    InitializeWorksheet ws
    
    '设置标题和测试方法标签
    SetupHeader ws, reportName
    
    '设置表格主体
    Dim lastRow As Long
    lastRow = SetupMainTable(ws, commonConfig)
    
    '设置基本信息并获取最后一行
    Dim finalRow As Long
    finalRow = SetupBasicInfo(ws, commonConfig, lastRow)
    
    '恢复原始引用样式
    If originalStyle <> Application.ReferenceStyle Then
        Application.ReferenceStyle = originalStyle
    End If
    
    '返回最后一行的下一行的行号
    SetupWorksheetStyle = finalRow + 1
End Function

'******************************************
' 过程: InitializeWorksheet
' 用途: 初始化工作表设置
'******************************************
Private Sub InitializeWorksheet(ByVal ws As Worksheet)
    Application.ActiveWindow.DisplayGridlines = False
    ws.Cells.Clear
    ws.Columns.ColumnWidth = 8
End Sub

'******************************************
' 过程: SetupHeader
' 用途: 设置标题和测试方法标签
'******************************************
Private Sub SetupHeader(ByVal ws As Worksheet, ByVal reportName As String)
    '设置标题
    With ws.Range(ws.Cells(1, 3), ws.Cells(1, 13))
        .Merge
        .Value = reportName
        .HorizontalAlignment = xlCenter
        .VerticalAlignment = xlCenter
        .Font.Name = "微软雅黑"
        .Font.Bold = True
        .Font.Size = 12
        .Borders.LineStyle = xlContinuous
    End With
    
    '设置"测试方法:"标签
    With ws.Cells(2, 2)
        .Value = "1.测试方法:"
        .Font.Bold = True
        .Font.Name = "微软雅黑"
        .Font.Size = 10
    End With
End Sub

'******************************************
' 函数: SetupMainTable
' 用途: 设置主数据表格
' 返回: 表格的最后一行行号
'******************************************
Private Function SetupMainTable(ByVal ws As Worksheet, ByVal commonConfig As Collection) As Long
    Dim lastRow As Long
    lastRow = 2 + commonConfig("StepDetails").Count
    
    '设置表格结构
    SetupTableStructure ws, lastRow
    
    '设置表格内容
    FillTableContent ws, commonConfig
    
    SetupMainTable = lastRow
End Function

'******************************************
' 过程: SetupTableStructure
' 用途: 设置表格结构（表头、边框、列宽）
'******************************************
Private Sub SetupTableStructure(ByVal ws As Worksheet, ByVal lastRow As Long)
    With ws.Range(ws.Cells(3, 3), ws.Cells(lastRow + 1, 13))
        '设置表头
        SetupTableHeader ws
        
        '设置边框
        SetupTableBorders ws.Range(ws.Cells(3, 3), ws.Cells(lastRow + 1, 13))
        
        '设置列宽
        SetupColumnWidths ws
    End With
End Sub

'******************************************
' 函数: SetupBasicInfo
' 用途: 设置基本信息区域
' 参数: 
'   - ws: 工作表对象
'   - commonConfig: 公共配置集合
'   - lastRow: 上一个表格的最后一行
' 返回: 第二行信息的行号
'******************************************
Private Function SetupBasicInfo(ByVal ws As Worksheet, ByVal commonConfig As Collection, ByVal lastRow As Long) As Long
    Dim infoRow As Long
    infoRow = lastRow + 3
    
    With ws
        '设置第一行信息
        SetupInfoRow ws, infoRow, commonConfig, True
        
        '设置第二行信息
        SetupInfoRow ws, infoRow + 1, commonConfig, False
    End With
    
    '返回第二行信息的行号
    SetupBasicInfo = infoRow + 1
End Function

'******************************************
' 函数: ValidateRawData
' 用途: 验证原始数据的有效性
' 参数: rawData - 原始数据集合
' 返回: Boolean值，表示数据是否有效
'******************************************
Private Function ValidateRawData(ByVal rawData As Collection) As Boolean
    On Error Resume Next
    
    '检查必要的数据集是否存在
    If rawData.Count < 3 Then
        MsgBox "缺少必要的数据!", vbExclamation
        ValidateRawData = False
        Exit Function
    End If
    
    '检查每个数据集的有效性
    If rawData("cyclesData").Count = 0 Then
        MsgBox "循环数据为空!", vbExclamation
        ValidateRawData = False
        Exit Function
    End If
    
    '...其他验证...
    
    ValidateRawData = True
End Function



