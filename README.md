# Active Directory Account Lockout Auditing & Notification - Step-by-Step Guide

## 🔧 Step 1: Enable Audit Policies on Domain Controller  
Run the following commands on each Domain Controller to ensure proper auditing is enabled for account management and lockouts:

```powershell
auditpol /set /category:"Account Management" /success:enable /failure:enable
auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
auditpol /set /category:"Policy Change" /success:enable /failure:enable
```

### ✅ Verify Audit Policies:
```powershell
auditpol /get /category:"Account Management"
auditpol /get /category:"Logon/Logoff"
auditpol /get /category:"Policy Change"
```

Ensure you see `Success and Failure` on all relevant categories.

---

## 🔓 Step 2: Unlock Test User Before Testing Lockout
Make sure the account you are going to test is **not currently locked**. Unlock it using:

```powershell
Unlock-ADAccount -Identity "TestUser"
```

---

## 🚫 Step 3: Simulate Account Lockout via LDAP Failed Binds  
Use repeated failed LDAP authentication to trigger a lockout for the test user.

```powershell
$Username = "TestUser"
$Domain = "YourDomain"
$WrongPassword = ConvertTo-SecureString "WrongPass123" -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ("$Domain\$Username", $WrongPassword)

for ($i = 1; $i -le 6; $i++) {
    try {
        $entry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://your-dc.yourdomain.com", $Credential.UserName, $WrongPassword)
        $null = $entry.NativeObject
    } catch {
        Write-Host "❌ Failed attempt $i"
    }
}
```

---

## 📧 Step 4: Notification Script
After lockout, run the script to capture the latest Event ID 4740 and send an email notification.

Update the script placeholders for:
- SMTP Server
- Sender Email
- Recipient Emails
- Your Domain and DC Hostname
- Test User Account

---

## 🔍 Step 5: Validate Results
- Confirm that Event ID 4740 is written to the **Security Event Log**.
- Confirm the email notification was received with lockout details.

---

## ✅ Done.
You now have auditing, lockout simulation, and email notification fully operational for AD account lockouts.

---
## 📄 Notes:
- `auditpol` changes are temporary. For permanent policy, configure via **GPO**.
- Always verify your policies on each DC individually.
