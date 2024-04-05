param(
    [switch]$NoDisableAdapter,         # �������������������Ŀ��أ�����ڹر��ȵ�ʱ�������������������������ʹ�ô˿���
    [switch]$EnableHotspot,            # �����ȵ�Ŀ���
    [switch]$DisableHotspot,           # �����ȵ�Ŀ���
    [switch]$EnableAdapter,            # �������������������Ŀ���
    [switch]$DisableAdapter            # �������������������Ŀ���
)

# ����ʾ����
# --NoDisableAdapter �� -NDA: �ڹر�WiFi�ȵ�ʱ������������������������
# --EnableHotspot �� -EH: ֱ�ӿ���WiFi�ȵ㡣
# --DisableHotspot �� -DH: ֱ�ӹر�WiFi�ȵ㡣
# --EnableAdapter �� -EA: ֱ����������������������
# --DisableAdapter �� -DA: ֱ�ӽ�������������������

Add-Type -AssemblyName System.Runtime.WindowsRuntime  # ���� Windows Runtime ����
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]

# �ȴ��첽������ɵĺ���
Function Await($WinRtTask, $ResultType) { 
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType) 
    $netTask = $asTask.Invoke($null, @($WinRtTask)) 
    $netTask.Wait(-1) | Out-Null 
    $netTask.Result 
} 

# �ȴ��첽������ɵĺ��������û�з��ؽ���Ĳ�����
Function AwaitAction($WinRtAction) { 
    $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and !$_.IsGenericMethod })[0] 
    $netTask = $asTask.Invoke($null, @($WinRtAction)) 
    $netTask.Wait(-1) | Out-Null 
} 

# ���û���� WiFi �������ĺ���
Function EnableDisableWiFiAdapter($enable) {
    try {
        $wifiAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like '*Wireless*' }  # ��ȡ��������������
        if ($wifiAdapter) {
            if ($enable) {
                Enable-NetAdapter -Name $wifiAdapter.Name -Confirm:$false  # ����������
            } else {
                Disable-NetAdapter -Name $wifiAdapter.Name -Confirm:$false  # ����������
            }
        } else {
            Write-Host "Wireless adapter not found."  # ���δ�ҵ�����������ʾ��Ϣ���˳�
            exit
        }
    } catch {
        Write-Host "An error occurred while trying to enable/disable the wireless adapter: $_"  # �����쳣���
        exit
    }
}

# ���û�����ȵ�ĺ���
Function ManageHotspot($enable) {
    try {
        $connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile()  # ��ȡ�������������ļ�
        if ($connectionProfile -eq $null) {
            Write-Host "No internet connection profile found. Please check your network connection."  # ����Ҳ������������ļ�������ʾ��Ϣ���˳�
            exit
        }

        $tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($connectionProfile)  # ���������ȵ������

        if ($enable) { 
            Await ($tetheringManager.StartTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])  # �����ȵ�
            Write-Host "Network sharing has been enabled."  # ��ʾ��Ϣ
        } else { 
            Await ($tetheringManager.StopTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])  # �ر��ȵ�
            Write-Host "Network sharing has been disabled."  # ��ʾ��Ϣ
            if (!$NoDisableAdapter) {  # ���δָ�������������������������
                EnableDisableWiFiAdapter $false
                Start-Sleep -Seconds 5  # �ȴ�5������ȷ����������ͣ��
            }
        }
    } catch {
        Write-Host "An error occurred: $_"  # �����쳣���
    }
}

# ���������в�����ִ����Ӧ����
if ($EnableAdapter) {
    EnableDisableWiFiAdapter $true
}
elseif ($DisableAdapter) {
    EnableDisableWiFiAdapter $false
}
elseif ($EnableHotspot) {
    EnableDisableWiFiAdapter $true
    ManageHotspot $true
}
elseif ($DisableHotspot) {
    ManageHotspot $false
}
else {
    # ���û�и���ֱ�ӵ��������ݵ�ǰ״ִ̬��Ĭ�ϲ���
    try {
        EnableDisableWiFiAdapter $true
        Start-Sleep -Seconds 5  # �ȴ�5������ȷ������������
        $connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile()
        if ($connectionProfile -eq $null) {
            Write-Host "No internet connection profile found. Please check your network connection."
            exit
        }
        $tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($connectionProfile)
        if ($tetheringManager.TetheringOperationalState -eq 1) { 
            ManageHotspot $false
        } else { 
            ManageHotspot $true
        }
    } catch {
        Write-Host "An error occurred: $_"
    }
}