function Test-ADInternalTimeSync {
    [CmdletBinding()]
    Param()
    <#
    .SYNOPSIS
    Check AD Last Backup Date
    
    .DESCRIPTION
    This script Checks AD for the last backup date

    .EXAMPLE
    Run as a scheduled task.  Use Event Log consolidation tools to pull and alert on issues found.

    .EXAMPLE
    Run in verbose mode if you want on-screen feedback for testing
   
    .NOTES
    Authors: Mike Kanakos, Greg Onstot

    Event Source 'PSMonitor' will be created

    EventID Definition:
    17050 - Failure
    17051 - Beginning of test
    17052 - Successful Test Result
    17053 - End of test
    17054 - Alert Email Sent
    #>

    Begin {
        Import-Module activedirectory
        if (![System.Diagnostics.EventLog]::SourceExists("PSMonitor")) {
            write-verbose "Adding Event Source."
            New-EventLog –LogName Application –Source "PSMonitor"
        }#end if
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17051 -EntryType Information -message "START of AD Backup Check ." -category "17051"
        $Domain = (Get-ADDomain).DNSRoot
        $Regex = '\d\d\d\d-\d\d-\d\d'
        $CurrentDate = Get-Date
        $MaxDaysSinceBackup = '1'
        
    }#End Begin

    Process {
        #get the date of last backup from repadmin command using regex
        $LastBackup = (repadmin /showbackup $Domain | Select-String $Regex |ForEach-Object { $_.Matches } | ForEach-Object { $_.Value } )[0]
        #Compare the last backup date to today's date
        $Result = (New-TimeSpan -Start $LastBackup -End $CurrentDate).Days
        Write-Verbose "Last Active Directory backup occurred on $LastBackup! $Result days is less than the alert criteria of $MaxDaysSinceBackup day."
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17052 -EntryType Information -message "SUCCESS - Last Active Directory backup occurred on $LastBackup! $Result days is less than the alert criteria of $MaxDaysSinceBackup day." -category "17052"

        #Test if result is greater than max allowed days without backup
        If ($Result -gt $MaxDaysSinceBackup) {
            Write-Verbose "Last Active Directory backup occurred on $LastBackup! $Result days is higher than the alert criteria of $MaxDaysSinceBackup day."
            $emailOutput = "Last Active Directory backup occurred on $LastBackup! $Result days is higher than the alert criteria of $MaxDaysSinceBackup day."
            Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17050 -EntryType Warning -message "ALERT - Backup not current.  $emailOutput" -category "17050"
            Send-Mail
        }#End if
    }#End Process
    End {
        Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17053 -EntryType Information -message "END of AD Backup Check ." -category "17053"
    }#End End
}#End Function

function Send-Mail {
    Param($emailOutput)
    Write-Verbose "Sending Email"
    Write-eventlog -logname "Application" -Source "PSMonitor" -EventID 17054 -EntryType Warning -message "ALERT Email Sent" -category "17054"
    Write-Verbose "Output is --  $emailOutput"
    
    #Mail Server Config
    $NBN = (Get-ADDomain).NetBIOSName
    $domainname = (Get-ADDomain).dnsroot
    $smtpServer = "<SMTPSERVER>.$Domainname"
    $smtp = new-object Net.Mail.SmtpClient($smtpServer)
    $msg = new-object Net.Mail.MailMessage

    #Send to list:    
    $msg.To.Add("<TargetUSER>@$domainname")
    $msg.To.Add("<TargetDL>@$domainname")
    
    #Message:
    $msg.From = "ADBackupCheck-$NBN@$Domainname"
    $msg.ReplyTo = "ADBackupCheck-$NBN@$Domainname"
    $msg.subject = "$NBN AD Backup Check Alert!"
    $msg.body = @"
        Time of Event: $((get-date))`r`n $emailOutput
"@

    #Send it
    $smtp.Send($msg)
}

Test-ADInternalTimeSync #-Verbose