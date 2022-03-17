#
# Powershell script to create a client VPN connection to a Meraki MX.  Generated using:
# https://www.ifm.net.nz/cookbooks/meraki-client-vpn.html
#
# Configuration Parameters
$ProfileName = 'DigitalXRAID Headoffice VPN'
$DnsSuffix = 'digitalxraid.net'
$ServerAddress = '188.127.76.2'
$L2tpPsk = 'HwsRN*A7srp4s%%We4Ug'

#
# Build client VPN profile
# https://docs.microsoft.com/en-us/windows/client-management/mdm/vpnv2-csp
#

# Define VPN Profile XML
$ProfileNameEscaped = $ProfileName -replace ' ', '%20'
$ProfileXML =
	'<VPNProfile>
		<RememberCredentials>false</RememberCredentials>
		<DnsSuffix>'+$dnsSuffix+'</DnsSuffix>
		<NativeProfile>
			<Servers>' + $ServerAddress + '</Servers>
			<RoutingPolicyType>SplitTunnel</RoutingPolicyType>
			<NativeProtocolType>l2tp</NativeProtocolType>
			<L2tpPsk>'+$L2tpPsk+'</L2tpPsk>
		</NativeProfile>
'

# Routes to include in the VPN
$ProfileXML += "  <Route><Address>10.0.200.0</Address><PrefixSize>24</PrefixSize><ExclusionRoute>false</ExclusionRoute></Route>`n"
$ProfileXML += "  <Route><Address>10.0.1.0</Address><PrefixSize>24</PrefixSize><ExclusionRoute>false</ExclusionRoute></Route>`n"
$ProfileXML += "  <Route><Address>10.0.2.0</Address><PrefixSize>24</PrefixSize><ExclusionRoute>false</ExclusionRoute></Route>`n"
$ProfileXML += "  <Route><Address>172.16.2.0</Address><PrefixSize>25</PrefixSize><ExclusionRoute>false</ExclusionRoute></Route>`n"

$ProfileXML += '</VPNProfile>'

# Convert ProfileXML to Escaped Format
$ProfileXML = $ProfileXML -replace '<', '&lt;'
$ProfileXML = $ProfileXML -replace '>', '&gt;'
$ProfileXML = $ProfileXML -replace '"', '&quot;'

# In case we are running this from the SYSTEM account get the SID of the currently logged in user
# https://docs.microsoft.com/en-us/windows-server/remote/remote-access/vpn/always-on-vpn/deploy/vpn-deploy-client-vpn-connections
try
{
	$username = Get-WmiObject -Class Win32_ComputerSystem | Select-Object username
	$objuser = New-Object System.Security.Principal.NTAccount($username.username)
	$sid = $objuser.Translate([System.Security.Principal.SecurityIdentifier])
	$SidValue = $sid.Value
}
catch [Exception]
{
	$Message = "Unable to get user SID. User may be logged on over Remote Desktop"
	Write-Host $Message
	exit
}

# Define WMI-to-CSP Bridge Properties
$nodeCSPURI = './Vendor/MSFT/VPNv2'
$namespaceName = 'root\cimv2\mdm\dmmap'
$className = 'MDM_VPNv2_01'

# Define WMI Session
$session = New-CimSession
$options = New-Object Microsoft.Management.Infrastructure.Options.CimOperationOptions
$options.SetCustomOption("PolicyPlatformContext_PrincipalContext_Type", "PolicyPlatform_UserContext", $false)
$options.SetCustomOption("PolicyPlatformContext_PrincipalContext_Id", "$SidValue", $false)

# Detect and Delete Previous VPN Profile
try
{
	$deleteInstances = $session.EnumerateInstances($namespaceName, $className, $options)
	foreach ($deleteInstance in $deleteInstances)
	{
		$InstanceId = $deleteInstance.InstanceID
		if ("$InstanceId" -eq "$ProfileNameEscaped")
		{			$session.DeleteInstance($namespaceName, $deleteInstance, $options)
			Write-Host "Removed '$ProfileName' profile"
		}
	}
}
catch [Exception]
{
	Write-Host "Unable to remove existing outdated instance(s) of $ProfileName profile: $_"
	exit
}

#
# Create VPN Profile
#

try
{
	$newInstance = New-Object Microsoft.Management.Infrastructure.CimInstance $className, $namespaceName
	$property = [Microsoft.Management.Infrastructure.CimProperty]::Create('ParentID', "$nodeCSPURI", 'String', 'Key')
	$newInstance.CimInstanceProperties.Add($property)
	$property = [Microsoft.Management.Infrastructure.CimProperty]::Create('InstanceID', "$ProfileNameEscaped", 'String', 'Key')
	$newInstance.CimInstanceProperties.Add($property)
	$property = [Microsoft.Management.Infrastructure.CimProperty]::Create('ProfileXML', "$ProfileXML", 'String', 'Property')
	$newInstance.CimInstanceProperties.Add($property)

	$session.CreateInstance($namespaceName, $newInstance, $options) | Out-Null
	Write-Host "Created '$ProfileName' profile."
}
catch [Exception]
{
	Write-Host "Unable to create $ProfileName profile: $_"
	exit
}

# Create registry key to allow connections to an MX behind NAT (Error 809)
New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\PolicyAgent -Name AssumeUDPEncapsulationContextOnSendRule -Value 2 -PropertyType DWORD -Force | Out-Null

