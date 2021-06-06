.DESCRIPTION
	This script checks the VMTools status to determine if the desktop is frozen or not and issues either a soft restart or a hard reset depending on the state of the desktop.  It checks with the connection server and ignores any desktops that have a Connected session.
	
	It must be run on a View Connection Server that has VMware PowerCLI installed.
	
	.PARAMETER Whatif
	Only report what actions the script would do, do not issue any commands.  Useful for testing.

	.PARAMETER VCServer
	The DNS resolvable name (or IP Address) of the vCenter server.

	.PARAMETER wait
	The number of seconds to wait between desktop restarts. Defaults to 10 seconds
	
	.PARAMETER Duration
	The total duration of the sessions you want to reset. Defaults to "*day*". This means that all connections with a duration containing "day" will be reset
	
	.LINK
	http://virtuallyjason.blogspot.com
	
	Author: Jason Coleman
	Last Modified: 10/10/2013
#> 

# Global variables
$VCServer		= ""
$Duration		= ""
$DesktopPool	= ""

#Checks to ensure that all required snapins are available, aborts the script if they are not.
$registeredSnapins = get-pssnapin -registered | select name
if (!($registeredSnapins -match "VMware.View.Broker") -or !($registeredSnapins -match "VMware.VimAutomation.Core"))
{
	write-output "Please run from a View Connection Server with the VMware PowerCLI snapins installed."
	Return
}

# Load the VMware snapins
add-pssnapin VMware.VimAutomation.Core
add-pssnapin VMware.View.Broker

#Check if desktop pool name is specified and check if pool exists
if ($DesktopPool) 
	{
		Try
		{
			Write-Host "Checking if specified desktop pool exists..."
			Get-Pool -pool_id $DesktopPool -ErrorAction Stop | out-null
		}
		Catch
		{
			write-host "Error: Desktop pool with name $DesktopPool not found. Exiting script."
			Exit 101
		}
	}
else
	{
		Write-Host "Error: Desktop Pool not specified. Exiting script."
		Exit 100
	}

#Connect to the vCenter Server
if ($VCServer) 
	{
		Try
		{
			Write-Host "Checking is specified vSphere server is reachable..."
			Connect-VIServer $VCServer -ErrorAction Stop -WarningAction SilentlyContinue
		}
		Catch
		{
			write-host "Error: VCServer with name $VCServer not found. Exiting script."
			Exit 151
		}
	}
else
	{
		Write-Host "Error: VCServer not specified. Exiting script."
		Exit 150
	}

Write-Host 
Write-Host ----------------------------------------------------------------------------------------------------------------

#Gets a list of all disconnected VMware View sessions from a specified desktop pool which exceed the specified duration.
$remoteSessions = Get-RemoteSession | where {$_.duration -like $Duration -and $_.pool_id -eq $DesktopPool}

if ($remoteSessions.Count -eq 0)
{
	Write-Host "No desktops to delete. Exiting script"
	Exit 0
}
else
{
	Write-Host "Found $($remoteSessions.Count) desktop(s) to reset."
	Write-Host
	foreach ($VMName in $remoteSessions)
	{
		#Remove domainname from FQDN
		Write-Host "Extracting hostname from $($VMName.DNSName)"
		$Hostname = $($VMName.DNSName).Substring(0, $($VMName.DNSName).IndexOf('.'))
			
		#Get VM from vSphere, filtered by the VM name.  
		#Get-view was used instead of get-VM in order to access GuestHeartbeatStatus
		$thisVM = Get-View -ViewType VirtualMachine -Filter @{"Name" = $Hostname}
		
		#If the HeartBeatStatus is green, use a soft restart
		if ($thisVM.GuestHeartbeatStatus -eq "green")
		{
			write-output "Soft Restart: $($thisVm.name)"
			if (!($WhatIf))
			{
				get-vm -name $thisVM.name | Restart-VMGuest | out-null
				Write-Host --------------------------------------------------------------
			}
		}
		#if the HeartBeatStatus is red, use a hard reset
		elseif ($thisVM.GuestHeartbeatStatus -eq "red")
		{
			write-output "Hard Reset: $($thisVM.name)"
			if (!($WhatIf))
			{
				get-vm -name $thisVM.name | stop-VM -confirm:$false | out-null
				start-sleep 15
				get-vm -name $thisVM.name | start-VM | out-null
				Write-Host --------------------------------------------------------------
			}
		}
		#If the HeartBeatStatus is gray, check the power state of the VM and hard reset if it's powered on.
		else
		{
			if ($thisVM.summary.runtime.powerstate -eq "poweredOff")
			{
				write-output "Ignoring Powered Off VM: $($thisVM.name)"
			}
			elseif ($thisVM.summary.runtime.powerstate -eq "poweredOn")
			{
				write-output "Hard Reset: $($thisVM.Name)"
				if (!($WhatIf))
				{
					get-vm -name $thisVM.name | stop-VM -confirm:$false | out-null
					start-sleep 15
					get-vm -name $thisVM.name | start-VM | out-null
					Write-Host --------------------------------------------------------------
				}
			}
			else
			{
				write-output "--> Unknown Power State: $($thisVM.summary.runtime.powerstate) for VM: $($thisVM.Name)"
			}
		}
		sleep 10
	}
}

#clean up after the script is completed
Disconnect-VIServer $VCServer -Confirm:$False
remove-pssnapin VMware.VimAutomation.Core
remove-pssnapin VMware.View.Broker
}