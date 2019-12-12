Function UserExit(sType, sWhen, sDetail, bSkip)

    oLogging.CreateEntry "UserExit: started: " & sType & " " & sWhen & " " & sDetail, LogTypeInfo
    UserExit = Success

End Function

Function SetMakeAlias()
    oLogging.CreateEntry "UserExit: Running function SetMakeAlias ", LogTypeInfo
    sMake = oEnvironment.Item("Make")
    SetMakeAlias = ""
    oLogging.CreateEntry "UserExit: Make is now " & sMake, LogTypeInfo

    Select Case sMake
        Case "Dell Computer Corporation", "Dell Inc.", "Dell Computer Corp."
			SetMakeAlias = "Dell"

        Case "Matsushita Electric Industrial Co.,Ltd.", "Panasonic", "Panasonic Corporation"
			SetMakeAlias = "Panasonic"	

        Case "VMware, Inc."
			SetMakeAlias = "VMware"

		Case "SAMSUNG ELECTRONICS CO., LTD."
			SetMakeAlias = "Samsung"
			
		Case "Microsoft Corporation"
			SetMakeAlias = "Microsoft"
		
		Case "HP", "Hewlett-Packard"
			SetMakeAlias = "HP"
		
        Case Else
			SetMakeAlias = sMake
			oLogging.CreateEntry "UserExit: Alias rule not found.  MakeAlias will be set to Make value." , LogTypeInfo
    End Select
    
	oLogging.CreateEntry "UserExit: MakeAlias has been set to " & SetMakeAlias, LogTypeInfo
End Function

Function SetModelAlias()
    oLogging.CreateEntry "UserExit: Running function SetModelAlias", LogTypeInfo
    sMake = oEnvironment.Item("MakeAlias")
    sModel = oEnvironment.Item("Product")
	sPath = oEnvironment.Item("DeployRoot") & "\Scripts\CUSTOM_MakeModel.xml"
    SetModelAlias = ""
    oLogging.CreateEntry "UserExit: Make is now " & sMake, LogTypeInfo
    oLogging.CreateEntry "UserExit: Model is now " & sModel, LogTypeInfo
	oLogging.CreateEntry "UserExit: Path is now " & sPath, LogTypeInfo

	Set xmlFile = CreateObject("MSXML2.DOMDocument.6.0")

	xmlFile.async = false
	xmlFile.SetProperty "SelectionLanguage", "XPath"
	xmlFile.load(sPath)

	SearchSting = "//Make[@name='" & sMake & "']/Model[contains('" & sModel & "', @name)]"
	oLogging.CreateEntry "UserExit: SearchSting is now " & SearchSting, LogTypeInfo
	
	Set Root = xmlFile.documentElement
	Set childNode = Root.SelectSingleNode(SearchSting)

	SetModelAlias = childNode.getAttribute("value")

    oLogging.CreateEntry "UserExit: ModelAlias has been set to " & SetModelAlias, LogTypeInfo
    oLogging.CreateEntry "UserExit: Departing...", LogTypeInfo
End Function

Function SetBIOSVersionAlias() 
    oLogging.CreateEntry "UserExit: Running function SetBIOSVersionAlias", LogTypeInfo
    Dim objWMI
    Dim objResults
    Dim objInstance
    Dim SMBIOSBIOSVersion
    
    Set objWMI = GetObject("winmgmts:") 
    Set objResults = objWMI.ExecQuery("SELECT * FROM Win32_BIOS")
        If Err then
        oLogging.CreateEntry "Error querying Win32_BIOS: " & Err.Description & " (" & Err.Number & ")", LogTypeError
    Else
        For each objInstance in objResults 
            If Not IsNull(objInstance.SMBIOSBIOSVersion) Then 
                    SMBIOSBIOSVersion = Trim(objInstance.SMBIOSBIOSVersion) 
            End If 
        Next
    End If
    'SMBIOSBIOSVersion = Replace(SMBIOSBIOSVersion, " ", "")
    'SMBIOSBIOSVersion = Replace(SMBIOSBIOSVersion, ".", "")
    SetBIOSVersionAlias = SMBIOSBIOSVersion    
    oLogging.CreateEntry "UserExit: BIOSVersionAlias has been set to " & SMBIOSBIOSVersion, LogTypeInfo
    oLogging.CreateEntry "UserExit: Departing...", LogTypeInfo
End Function
