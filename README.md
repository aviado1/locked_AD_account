# Active Directory Account Lockout Auditing & Notification - Full Step-by-Step Guide

## 🔧 Step 1: Enable Audit Policies on Domain Controller  
Run the following commands on **each Domain Controller** to ensure proper auditing is enabled for account management and lockouts:

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

## 🔍 Step 3: Check Lockout Status
Verify if the user is locked out before starting the test:
```powershell
Search-ADAccount -LockedOut -UsersOnly | Select-Object SamAccountName, Name, Enabled
```

---

## 🚫 Step 4: Simulate Account Lockout  
### Option 1: Using LDAP Failed Binds
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

### Option 2: Using `net use` to Trigger Lockout via Failed SMB Authentication
```powershell
for ($i = 1; $i -le 5; $i++) {
    cmd /c "net use \\your-dc\IPC$ /user:YourDomain\TestUser WrongPassword123"
}
```

---

## 🔍 Step 5: Check for Lockout Event in Security Log
```powershell
Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    ID = 4740
    StartTime = (Get-Date).AddHours(-2)
} | Where-Object { $_.Message -like "*TestUser*" }
```

---

## 📧 Step 6: Notification Script
After confirming lockout, run the email notification script to capture the latest Event ID 4740 and send a detailed email.
Update the script placeholders for:
- SMTP Server
- Sender Email
- Recipient Emails
- Domain Controller Hostname
- Domain Name
- Test User Account

---

## ✅ Step 7: Validate Results
- Confirm Event ID 4740 is written to the **Security Event Log**.
- Confirm the email notification was received with lockout details.
- Confirm user status shows as locked out.

```powershell
Search-ADAccount -LockedOut -UsersOnly | Select-Object SamAccountName, Name, Enabled
```

---

## 📄 Notes:
- `auditpol` changes are temporary. For permanent policy, configure via **GPO**.
- Always verify your policies on each DC individually.
- These steps are for **lab / testing purposes only.**
