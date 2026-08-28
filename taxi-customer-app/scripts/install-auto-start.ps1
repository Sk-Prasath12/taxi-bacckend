# Registers start-stack.ps1 to run when Windows starts (keeps server alive after reboot).
# Run once as Administrator recommended.
$taskName = "TaxiCustomerAppServerStack"
$script = Join-Path $PSScriptRoot "start-stack.ps1"

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""

$trigger = New-ScheduledTaskTrigger -AtLogOn

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
  -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 0)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
  -Settings $settings -Description "Starts Docker + HTTPS tunnel for Taxi Customer APK" -Force

Write-Host "Registered Windows task: $taskName"
Write-Host "Docker + tunnel will start automatically when you log in to Windows."
Write-Host "To remove: Unregister-ScheduledTask -TaskName $taskName -Confirm:`$false"
