	Author: Dietmar Haimann
	Requirements:
		Must have:
			Client Management Solutions - HP Client Management Script Library
			https://ftp.hp.com/pub/caps-softpaq/cmit/hp-cmsl.html
		
			ConfigMgr-Console installed
			
			The followings folders:
				C:\Util\DriverFactory\ 			> place the script in this folder
				C:\Util\DriverFactory\Extrafiles 	> place the password.bin, ssm.cab and ssm.exe in this folder
				C:\Util\DriverFactory\Models		> place the HPModels.csv in this folder
				C:\DriverFactory			> this is the folder where the magic happens
				
			File called C:\Util\DriverFactory\Models\HPModels.csv with the following content:
			
			Manufacturer;HPModel;ProdCode
			HP;HP EliteBook 840 G1;198F
			HP;HP EliteBook 840 G2;2216
			HP;HP EliteBook 840 G3;8079
			
			Network share for source files like
			\\fileserver\share$\OSD\HP BIOS Update Packages
			
		Optional:
			SMTP Username and Password
			SMTP Server Name
			Sender E-Mail Address
			Recipient E-Mail Address
			Microsoft Teams with configured incoming webhook
			https://www.scconfigmgr.com/2017/10/06/configmgr-osd-notification-service-teams/
			
	Configure:
			Go to C:\Util\DriverFactory\DriverFactory.json and configure for your needs
			No need to do any settings in the script directly
			
	Description:
		The script does the following:
			Reads C:\Util\DriverFactory\DriverFactory.json for settings
			Creates folders C:\DriverFactory\Download, C:\DriverFactory\Extracted, C:\DriverFactory\TempFolder
			Reads HPModels.csv
			Connects to HP and fetch Softpaq list
			Compairs the existing ConfigMgr package version with online version
			If version is different it downloads the new version
			Extracts the files and copies the files to file server
				\\fileserver\share$\OSD\HP BIOS Update Packages\HP EliteDesk 800 G5 DM 65W\02.02.00
				\\fileserver\share$\OSD\HP BIOS Update Packages\HP EliteDesk 800 G5 DM 65W\02.03.01
				...
			Creates ConfigMgr package in configurable folder structure
				Manufacturer:	HP
				Name:			BIOS - HP EliteDesk 800 G5 DM 65W\02
				Version:		02.03.01
				Description:	Model 8594, Version 02.03.01, Release Date 2019-10-15
				
			Distributes the package to Distribution Point group
			Writes log to C:\DriverFactory\Get-asHPBIOSUpdates.log
			Sends summary via E-Mail
			Sends summary to Microsoft Teams
			
	Thanks:
		Adam Bertram
			@adbertram
			https://adamtheautomator.com/send-mailmessage/
			https://adamtheautomator.com/building-logs-for-cmtrace-powershell/
		
		Terence Beggs
			@terencebeggs
			https://www.scconfigmgr.com/2017/10/06/configmgr-osd-notification-service-teams/
		
		Jordan Benzing
			@JordanTheITguy
			https://www.scconfigmgr.com/2018/07/12/send-your-patching-manifest-to-teams/
			
		Gary Blok
			@gwblok
			https://garytown.com/hp-driver-packs-download-cm-import-via-powershell/
			
		Nathan Kofahl
			@nkofahl
			https://twitter.com/nkofahl
		
		... and so many more!
