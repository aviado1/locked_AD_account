<#
DESCRIPTION:
-----------
This script demonstrates how to configure Windows Audit Policies on a Domain Controller 
to ensure Account Lockout (Event ID 4740) events are logged. It also simulates an account 
lockout event via repeated failed LDAP authentication attempts, captures the latest lockout 
event from the Security Event Log, and sends an HTML-formatted email with the lockout details.

REQUIREMENTS BEFORE RUNNING:
----------------------------
1. Ensure the script is executed on a Domain Controller (DC).
2. Ensure the 'ActiveDirectory' module is available and imported.
3. Ensure SMTP relay is allowed from the DC to your mail server.
4. Replace placeholders with appropriate domain and user details.

IMPORTANT: 
----------
Audit Policy changes done via 'auditpol' are temporary until overwritten by Group Policy.
To make these settings permanent, configure them via GPO.

STEPS:
------
1. Enable Auditing for relevant categories (Account Management, Logon/Logoff, Policy Change).
2. Verify Audit Policies are set.
3. Unlock the test account.
4. Force multiple invalid login attempts to trigger lockout.
5. Capture latest lockout event and email its details.
#>

# Import Active Directory module
Import-Module ActiveDirectory

# Step 1 - Enable Audit Policies
auditpol /set /category:"Account Management" /success:enable /failure:enable
auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
auditpol /set /category:"Policy Change" /success:enable /failure:enable

# Step 2 - Verify Audit Policies are set
auditpol /get /category:"Account Management"
auditpol /get /category:"Logon/Logoff"
auditpol /get /category:"Policy Change"

# Step 3 - Unlock the test user account
Unlock-ADAccount -Identity "TestUser"
Write-Host "✅ User 'TestUser' has been unlocked."

# Step 4 - Simulate failed login attempts to cause lockout
$Username = "TestUser"
$Domain = "YourDomain"
$WrongPassword = ConvertTo-SecureString "WrongPass123" -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ("$Domain\$Username", $WrongPassword)

for ($i = 1; $i -le 6; $i++) {
    try {
        $entry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://YourDC.YourDomain.com", $Credential.UserName, $WrongPassword)
        $null = $entry.NativeObject
    } catch {
        Write-Host "❌ Failed attempt $i"
    }
}
Write-Host "🔔 Finished sending invalid credentials to lock user '$Username'."

# Step 5 - Capture latest lockout event and send notification email
# Get the latest lockout event (Event ID 4740)
$AccountLockOutEvent = Get-EventLog -LogName "Security" -InstanceID 4740 -Newest 1
$LockedAccount = $($AccountLockOutEvent.ReplacementStrings[0])
$MailSubject = "User - $LockedAccount Notice: User Account locked out $LockedAccount"
$MailFrom = "noreply@yourdomain.com"
$MailTo = "recipient1@yourdomain.com, recipient2@yourdomain.com"

$Event = Get-EventLog -LogName Security -InstanceId 4740 -Newest 1
$EventDetails = $Event.Message
$EventDetailsFormatted = $EventDetails -replace '(Account Domain:\s*)(\S+)', '$1<span style="font-weight:bold; color:red;">$2</span>' `
                                            -replace '(Caller Computer Name:\s*)(\S+)', '$1<span style="font-weight:bold; color:red;">$2</span>'

# Prepare HTML-formatted email body
$MailBody = @"
<html>
<head>
<style>
  body {font-family: Arial, sans-serif;}
  table {border-collapse: collapse; width: 100%;}
  th, td {border: 1px solid #dddddd; text-align: left; padding: 8px;}
  th {background-color: #f2f2f2;}
  .styled-value {font-weight: bold; color: red;}
</style>
</head>
<body>
<h2>Account Lockout Details</h2>
<table>
  <tr>
    <th>Property</th>
    <th>Value</th>
  </tr>
  <tr>
    <td>Account</td>
    <td class="styled-value">$LockedAccount</td>
  </tr>
  <tr>
    <td>Time Generated</td>
    <td>$($Event.TimeGenerated)</td>
  </tr>
  <tr>
    <td>Event Details</td>
    <td>$EventDetailsFormatted</td>
  </tr>
</table>
<p style="font-size:small; color:gray;">
  Note: This email is generated by an automation running from Task Scheduler
</p>
</body>
</html>
"@

# Step 6 - Send email via SMTP
$SmtpClient = New-Object system.net.mail.smtpClient
$SmtpClient.host = "your.smtp.server"

$MailMessage = New-Object system.net.mail.mailmessage
$MailMessage.from = $MailFrom
$MailMessage.To.add($MailTo)
$MailMessage.IsBodyHtml = $true
$MailMessage.Subject = $MailSubject
$MailMessage.Body = $MailBody

$SmtpClient.Send($MailMessage)
Write-Host "📧 Lockout email has been sent."
