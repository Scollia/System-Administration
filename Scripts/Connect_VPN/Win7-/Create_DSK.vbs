strVPNName = "My_VPN"
strHost = "190.90.80.10"

Set objShell = CreateObject("Wscript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")
Const intForReading = 1
Const intForAppending = 8

strFile = objShell.ExpandEnvironmentStrings("%APPDATA%") & "\Microsoft\Network\Connections\Pbk\rasphone.pbk"

boolWrite = True
If objFSO.FileExists(strFile) = True Then
	Set objRASFile = objFSO.OpenTextFile(strFile, intForReading, False)
	strContents = objRASFile.ReadAll
	objRASFile.Close
	Set objRASFile = Nothing
	If InStr(LCase(strContents), LCase(strVPNName)) > 0 Then boolWrite = False
End If

If boolWrite = True Then
strContents = VbCrLf & _
	"[" & strVPNName & "]" & vbCrLf & _
	"Encoding=1" & vbCrLf & _
	"Type=2" & vbCrLf & _
	"AutoLogon=0" & vbCrLf & _
	"UseRasCredentials=1" & vbCrLf & _
	"DialParamsUID=5021906" & vbCrLf & _
	"Guid=F29BC5711801294C8AF6648CE3F336FF" & vbCrLf & _
	"BaseProtocol=1" & vbCrLf & _
	"VpnStrategy=1" & vbCrLf & _
	"ExcludedProtocols=0" & vbCrLf & _
	"LcpExtensions=1" & vbCrLf & _
	"DataEncryption=256" & vbCrLf & _
	"SwCompression=1" & vbCrLf & _
	"NegotiateMultilinkAlways=0" & vbCrLf & _
	"SkipNwcWarning=0" & vbCrLf & _
	"SkipDownLevelDialog=0" & vbCrLf & _
	"SkipDoubleDialDialog=0" & vbCrLf & _
	"DialMode=0" & vbCrLf & _
	"DialPercent=75" & vbCrLf & _
	"DialSeconds=120" & vbCrLf & _
	"HangUpPercent=10" & vbCrLf & _
	"HangUpSeconds=120" & vbCrLf & _
	"OverridePref=15" & vbCrLf & _
	"RedialAttempts=3" & vbCrLf & _
	"RedialSeconds=60" & vbCrLf & _
	"IdleDisconnectSeconds=0" & vbCrLf & _
	"RedialOnLinkFailure=0" & vbCrLf & _
	"CallbackMode=0" & vbCrLf & _
	"CustomDialDll=" & vbCrLf & _
	"CustomDialFunc=" & vbCrLf & _
	"CustomRasDialDll=" & vbCrLf & _
	"AuthenticateServer=0" & vbCrLf & _
	"ShareMsFilePrint=1" & vbCrLf & _
	"BindMsNetClient=1" & vbCrLf & _
	"SharedPhoneNumbers=0" & vbCrLf & _
	"GlobalDeviceSettings=0" & vbCrLf & _
	"PrerequisiteEntry=" & vbCrLf & _
	"PrerequisitePbk=" & vbCrLf & _
	"PreferredPort=VPN4-0" & vbCrLf & _
	"PreferredDevice=WAN Miniport (PPTP)" & vbCrLf & _
	"PreferredBps=0" & vbCrLf & _
	"PreferredHwFlow=1" & vbCrLf & _
	"PreferredProtocol=0" & vbCrLf & _
	"PreferredCompression=0" & vbCrLf & _
	"PreferredSpeaker=1" & vbCrLf & _
	"PreferredMdmProtocol=0" & vbCrLf & _
	"PreviewUserPw=1" & vbCrLf & _
	"PreviewDomain=0" & vbCrLf & _
	"PreviewPhoneNumber=0" & vbCrLf & _
	"ShowDialingProgress=1" & vbCrLf & _
	"ShowMonitorIconInTaskBar=1" & vbCrLf & _
	"CustomAuthKey=-1" & vbCrLf & _
	"AuthRestrictions=512" & vbCrLf & _
	"TypicalAuth=2" & vbCrLf & _
	"IpPrioritizeRemote=1" & vbCrLf & _
	"IpHeaderCompression=0" & vbCrLf & _
	"IpAddress=0.0.0.0" & vbCrLf & _
	"IpDnsAddress=0.0.0.0" & vbCrLf & _
	"IpDns2Address=0.0.0.0" & vbCrLf & _
	"IpWinsAddress=0.0.0.0" & vbCrLf & _
	"IpWins2Address=0.0.0.0" & vbCrLf & _
	"IpAssign=1" & vbCrLf & _
	"IpNameAssign=1" & vbCrLf & _
	"IpFrameSize=1006" & vbCrLf & _
	"IpDnsFlags=0" & vbCrLf & _
	"IpNBTFlags=1" & vbCrLf & _
	"TcpWindowSize=0" & vbCrLf & _
	"UseFlags=0" & vbCrLf & _
	"IpSecFlags=0" & vbCrLf & _
	"IpDnsSuffix=" & vbCrLf & _
	"DisableClassBasedDefaultRoute=1" & vbCrLf & _
	"AutoTiggerCapable=1" & vbCrLf & _
	"RouteVersion=1" & vbCrLf & _
	"NumRoutes=3" & vbCrLf & _
	"NumNrptRules=0" & vbCrLf & _
	"AutoTiggerCapable=1" & vbCrLf & _
	"" & VbCrLf & _
	"NETCOMPONENTS=" & VbCrLf & _
	"ms_server=1" & VbCrLf & _
	"ms_msclient=1" & VbCrLf & _
	"" & VbCrLf & _
	"MEDIA=rastapi" & VbCrLf & _
	"Port=VPN4-0" & VbCrLf & _
	"Device=WAN Miniport (PPTP)" & VbCrLf & _
	"" & VbCrLf & _
	"DEVICE=vpn" & VbCrLf & _
	"PhoneNumber=" & strHost & VbCrLf & _
	"AreaCode=" & VbCrLf & _
	"CountryCode=61" & VbCrLf & _
	"CountryID=61" & VbCrLf & _
	"UseDialingRules=0" & VbCrLf & _
	"Comment=" & VbCrLf & _
	"LastSelectedPhone=0" & VbCrLf & _
	"PromoteAlternates=0" & VbCrLf & _
	"TryNextAlternateOnFail=1"


	Set objRASFile = objFSO.OpenTextFile(strFile, intForAppending, True)
	objRASFile.Write strContents
	objRASFile.Close
	Set objRASFile = Nothing

	MsgBox "File modified."
Else
	MsgBox "File not modified."
End If