# -----------------------------------------
# PowerShell Script with Menu (Updated)
# -----------------------------------------

# 환경에 따라 오류 시 무시하고 계속 진행
$ErrorActionPreference = "SilentlyContinue"

#------------------------------------------------------------------------------
# [함수] 메인 메뉴 표시
#------------------------------------------------------------------------------
function Show-Menu {
    Write-Host "=========================================="
    Write-Host "        [ 작업 선택 메뉴 예시 ]"
    Write-Host "=========================================="
    Write-Host "1) 통합 설치 (크롬 유지 + 유용한 확장 + 마에스트로웹5/맘아이 무력화)"
    Write-Host "2) Thorium 브라우저 통합 설치 (Thorium + 유용한 확장 + 마에스트로웹5/맘아이 무력화)"
    Write-Host "3) Surfshark VPN 확장만 설치"
    Write-Host "4) 유용한 확장만 설치 (uBlock, Volume Master, FastForward, Surfshark VPN)"
    Write-Host "5) 마에스트로웹5 및 맘아이 무력화"
    Write-Host "6) 사지방 해제기 설치 (CCUpdater)"
    Write-Host "7) Proton VPN 설치"
    Write-Host "Q) 스크립트 종료"
    Write-Host "=========================================="
}

#------------------------------------------------------------------------------
# [함수] 크롬 확장 정책 설정 & 불필요한 확장 제거
#   - 특정 확장 ID를 "ExtensionInstallForcelist"에 등록해 자동 설치
#   - 그 외 확장 폴더는 삭제하여 크롬 재시작 시 강제 제거
#------------------------------------------------------------------------------
function Set-ChromePolicyAndRemoveExtensions {
    param(
        [String[]] $ExtensionIds
    )

    Write-Host "`n=== 크롬 정책 설정 및 불필요한 확장 제거 ==="
    try {
        # Chrome 정책 레지스트리 경로
        $chromePolicyPath = "HKLM:\Software\Policies\Google\Chrome\ExtensionInstallForcelist"

        # 상위 키가 없다면 생성 (HKLM:\Software\Policies\Google\Chrome)
        if (-not (Test-Path $chromePolicyPath.Replace("\ExtensionInstallForcelist",""))) {
            New-Item -Path ($chromePolicyPath.Replace("\ExtensionInstallForcelist","")) -Force | Out-Null
        }
        # ExtensionInstallForcelist 키가 없다면 생성
        if (-not (Test-Path $chromePolicyPath)) {
            New-Item -Path $chromePolicyPath -Force | Out-Null
        }

        # 필요한 확장들을 순서대로 정책 등록
        for($i=0; $i -lt $ExtensionIds.Count; $i++){
            $name  = ($i + 1).ToString()
            $value = ("{0};https://clients2.google.com/service/update2/crx" -f $ExtensionIds[$i])
            Set-ItemProperty -Path $chromePolicyPath -Name $name -Value $value -Type String
            Write-Host "  -> 확장ID [$($ExtensionIds[$i])] 정책 적용 완료 (키: $name)"
        }

        # 불필요한 확장 폴더 삭제
        $extensionDir = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions"
        if (Test-Path $extensionDir) {
            $allowed = $ExtensionIds
            Get-ChildItem $extensionDir -Directory | Where-Object {
                $allowed -notcontains $_.Name
            } | Remove-Item -Recurse -Force

            Write-Host "  -> 불필요한 확장 프로그램 폴더 제거 완료"
        }
        else {
            Write-Warning "  -> 크롬 확장 폴더가 존재하지 않습니다."
        }
    }
    catch {
        Write-Warning "크롬 확장 정책 설정/제거 중 오류 발생: $($_.Exception.Message)"
    }
}

#------------------------------------------------------------------------------
# [함수] 크롬 확장 정책 설정 (확장 폴더는 제거 X)
#   - 특정 확장 ID를 ExtensionInstallForcelist에 등록해 자동 설치
#   - 이미 설치된 다른 확장은 제거하지 않음
#------------------------------------------------------------------------------
function Set-ChromePolicyNoRemoveExtensions {
    param(
        [String[]] $ExtensionIds
    )

    Write-Host "`n=== 크롬 정책 설정 (기존 확장 폴더는 그대로 유지) ==="
    try {
        # Chrome 정책 레지스트리 경로
        $chromePolicyPath = "HKLM:\Software\Policies\Google\Chrome\ExtensionInstallForcelist"

        # 상위 키가 없다면 생성 (HKLM:\Software\Policies\Google\Chrome)
        if (-not (Test-Path $chromePolicyPath.Replace("\ExtensionInstallForcelist",""))) {
            New-Item -Path ($chromePolicyPath.Replace("\ExtensionInstallForcelist","")) -Force | Out-Null
        }
        # ExtensionInstallForcelist 키가 없다면 생성
        if (-not (Test-Path $chromePolicyPath)) {
            New-Item -Path $chromePolicyPath -Force | Out-Null
        }

        # 필요한 확장들을 순서대로 정책 등록
        for($i=0; $i -lt $ExtensionIds.Count; $i++){
            $name  = ($i + 1).ToString()
            $value = ("{0};https://clients2.google.com/service/update2/crx" -f $ExtensionIds[$i])
            Set-ItemProperty -Path $chromePolicyPath -Name $name -Value $value -Type String
            Write-Host "  -> 확장ID [$($ExtensionIds[$i])] 정책 적용 완료 (키: $name)"
        }

        Write-Host "  -> 기존 확장 폴더는 삭제하지 않았습니다."
    }
    catch {
        Write-Warning "크롬 확장 정책 설정 중 오류 발생: $($_.Exception.Message)"
    }
}

#------------------------------------------------------------------------------
# [함수] CCUpdater 다운로드 / 실행, cc2.exe → chrome.exe 실행
#------------------------------------------------------------------------------
function Run-CCUpdaterProcess {
    Write-Host "`n=== ccupdater.exe (사지방 해제기) 다운로드 및 실행 ==="

    $workDir = Join-Path $env:USERPROFILE "Downloads\CCUpdaterWork"
    if (-not (Test-Path $workDir)) {
        New-Item -ItemType Directory -Path $workDir | Out-Null
    }

    $ccUpdaterUrl  = "https://wiki.codingbot.kr/ckir/assets/download/ccupdater.exe"
    $ccUpdaterPath = Join-Path $workDir "ccupdater.exe"

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    try {
        Invoke-WebRequest -Uri $ccUpdaterUrl -OutFile $ccUpdaterPath
        Write-Host "  -> ccupdater.exe 다운로드 완료"
    }
    catch {
        Write-Warning "다운로드 중 오류: $($_.Exception.Message)"
        return
    }

    try {
        Start-Process -FilePath $ccUpdaterPath -Wait
        Write-Host "  -> ccupdater.exe 실행 완료"
    }
    catch {
        Write-Warning "ccupdater.exe 실행 중 오류: $($_.Exception.Message)"
        return
    }

    Write-Host "`n=== release.zip 처리 ==="

    $releaseZipPath     = Join-Path $workDir "release.zip"
    $releaseExtractPath = Join-Path $workDir "release"
    $cc2ExePath         = $null

    if (Test-Path $releaseZipPath) {
        try {
            if (Test-Path $releaseExtractPath) {
                Remove-Item $releaseExtractPath -Recurse -Force
            }
            New-Item -ItemType Directory -Path $releaseExtractPath | Out-Null

            Expand-Archive -Path $releaseZipPath -DestinationPath $releaseExtractPath -Force
            Write-Host "  -> release.zip 압축 해제 완료: $releaseExtractPath"
            $cc2ExePath = Join-Path $releaseExtractPath "cc2.exe"
        }
        catch {
            Write-Warning "release.zip 처리 중 오류: $($_.Exception.Message)"
            return
        }
    }
    else {
        Write-Warning "release.zip이 없습니다. cc2.exe를 검색합니다."
        $cc2ExeFound = Get-ChildItem -Path $workDir -Recurse -Filter "cc2.exe" -File -ErrorAction SilentlyContinue
        if ($cc2ExeFound) {
            $cc2ExePath = $cc2ExeFound[0].FullName
            Write-Host "  -> cc2.exe 발견 위치: $cc2ExePath"
        }
    }

    if ($cc2ExePath -and (Test-Path $cc2ExePath)) {
        try {
            $cc2Dir     = Split-Path $cc2ExePath -Parent
            $renamedExe = Join-Path $cc2Dir "chrome.exe"
            
            Rename-Item -Path $cc2ExePath -NewName "chrome.exe" -Force
            Write-Host "  -> cc2.exe를 chrome.exe로 이름 변경 완료"

            Start-Process -FilePath $renamedExe
            Write-Host "  -> chrome.exe 실행 (사지방 해제기 동작)"
        }
        catch {
            Write-Warning "cc2.exe 변경/실행 중 오류: $($_.Exception.Message)"
        }
    }
    else {
        Write-Warning "cc2.exe를 찾을 수 없습니다."
    }

    Write-Host "`n=== 사지방 해제기(CCUpdater) 작업이 완료되었습니다. ==="
}

#------------------------------------------------------------------------------
# [함수] Proton VPN 설치
#------------------------------------------------------------------------------
function Install-ProtonVPN {
    Write-Host "`n=== Proton VPN 설치 ==="

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $downloadUrl = "https://vpn.protondownload.com/download/ProtonVPN_v3.5.1_x64.exe"
    $tempFile    = Join-Path $env:TEMP "ProtonVPNSetup.exe"

    try {
        Write-Host "  -> Proton VPN 설치 파일 다운로드 중: $downloadUrl"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile

        Write-Host "  -> Proton VPN 설치 파일 실행 (Silent 모드 시도)"
        Start-Process -FilePath $tempFile -ArgumentList "/S" -Wait

        Write-Host "  -> Proton VPN 설치 완료 (정상 동작 여부는 확인 필요)"
    }
    catch {
        Write-Warning "Proton VPN 설치 중 오류: $($_.Exception.Message)"
    }
}

#------------------------------------------------------------------------------
# [함수] Thorium 브라우저 설치 및 설정
#------------------------------------------------------------------------------
function Install-ThoriumBrowser {
    Write-Host "`n=== Thorium 브라우저 설치 (AVX2 버전) ==="
    
    # Thorium 브라우저 다운로드 URL (최신 AVX2 버전)
    $thoriumUrl = "https://github.com/Alex313031/thorium/releases/latest/download/thorium_AVX2_mini_installer.exe"
    $installerPath = Join-Path $env:TEMP "thorium_installer.exe"
    
    try {
        # TLS 1.2 설정
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Thorium 설치 파일 다운로드
        Write-Host "  -> Thorium 브라우저 (AVX2) 다운로드 중..."
        Invoke-WebRequest -Uri $thoriumUrl -OutFile $installerPath
        
        # 설치 실행
        Write-Host "  -> Thorium 브라우저 설치 중..."
        Start-Process -FilePath $installerPath -ArgumentList "/silent" -Wait
        
        Write-Host "  -> Thorium 브라우저 (AVX2) 설치 완료"
    }
    catch {
        Write-Warning "Thorium 브라우저 설치 중 오류 발생: $($_.Exception.Message)"
    }
}

#------------------------------------------------------------------------------
# [함수] Thorium 브라우저용 확장 정책 설정
#------------------------------------------------------------------------------
function Set-ThoriumPolicyAndExtensions {
    param(
        [String[]] $ExtensionIds
    )

    Write-Host "`n=== Thorium 브라우저 정책 설정 ==="
    try {
        # Thorium 정책 레지스트리 경로
        $thoriumPolicyPath = "HKLM:\Software\Policies\Thorium\ExtensionInstallForcelist"
        
        # 상위 키가 없다면 생성
        if (-not (Test-Path $thoriumPolicyPath.Replace("\ExtensionInstallForcelist",""))) {
            New-Item -Path ($thoriumPolicyPath.Replace("\ExtensionInstallForcelist","")) -Force | Out-Null
        }
        # ExtensionInstallForcelist 키가 없다면 생성
        if (-not (Test-Path $thoriumPolicyPath)) {
            New-Item -Path $thoriumPolicyPath -Force | Out-Null
        }

        # 필요한 확장들을 순서대로 정책 등록
        for($i=0; $i -lt $ExtensionIds.Count; $i++){
            $name = ($i + 1).ToString()
            $value = ("{0};https://clients2.google.com/service/update2/crx" -f $ExtensionIds[$i])
            Set-ItemProperty -Path $thoriumPolicyPath -Name $name -Value $value -Type String
            Write-Host "  -> 확장ID [$($ExtensionIds[$i])] 정책 적용 완료 (키: $name)"
        }
    }
    catch {
        Write-Warning "Thorium 브라우저 확장 정책 설정 중 오류 발생: $($_.Exception.Message)"
    }
}

#------------------------------------------------------------------------------
# [옵션1] 통합 설치 (크롬 유지 + 유용한 확장 + 마에스트로웹5/맘아이 무력화)
#------------------------------------------------------------------------------
function Option1-IntegrateInstall {
    Write-Host "`n[1] 통합 설치 - 크롬 유지 + 유용한 확장 + 마에스트로웹5/맘아이 무력화"

    # (Option3와 동일한 확장 목록)
    $uBlockId      = "cjpalhdlnbpafiamejdnhcphjbkeiagm"  # uBlock Origin
    $volumeMasterId = "jghecgabfgfdldnmbfkhmffcabddioke" # Volume Master
    $fastForwardId = "icallnadddjmdinamnolclfjanhfoafe" # FastForward
    $surfsharkId   = "ailoabdmgclmfmhdagmlohpjlbpffblp"  # Surfshark VPN

    $extensionList = @($uBlockId, $volumeMasterId, $fastForwardId, $surfsharkId)

    # 1) 크롬 확장 정책 설정 + 불필요한 확장 제거 (통합 설치)
    Set-ChromePolicyAndRemoveExtensions -ExtensionIds $extensionList

    # 2) 마에스트로웹5 및 맘아이 무력화
    Write-Host "`n=== [통합 설치] - 마에스트로웹5/맘아이 무력화 실행 ==="
    Option4-MaestroWeb5MommyDisable

    Write-Host "`n=== [통합 설치] 최종 완료 ==="
}

#------------------------------------------------------------------------------
# [옵션2] Thorium 브라우저 통합 설치 (Thorium + 유용한 확장 + 마에스트로웹5/맘아이 무력화)
#------------------------------------------------------------------------------
function Option2-ThoriumInstall {
    Write-Host "`n[2] Thorium 브라우저 통합 설치"

    # Thorium 브라우저 설치
    Install-ThoriumBrowser

    # (Option3와 동일한 확장 목록)
    $uBlockId      = "cjpalhdlnbpafiamejdnhcphjbkeiagm"  # uBlock Origin
    $volumeMasterId = "jghecgabfgfdldnmbfkhmffcabddioke" # Volume Master
    $fastForwardId = "icallnadddjmdinamnolclfjanhfoafe" # FastForward
    $surfsharkId   = "ailoabdmgclmfmhdagmlohpjlbpffblp"  # Surfshark VPN

    $extensionList = @($uBlockId, $volumeMasterId, $fastForwardId, $surfsharkId)

    # 1) Thorium 브라우저용 확장 정책 설정
    Set-ThoriumPolicyAndExtensions -ExtensionIds $extensionList

    # 2) 마에스트로웹5 및 맘아이 무력화
    Write-Host "`n=== [Thorium 브라우저 통합 설치] - 마에스트로웹5/맘아이 무력화 실행 ==="
    Option4-MaestroWeb5MommyDisable

    Write-Host "`n=== [Thorium 브라우저 통합 설치] 최종 완료 ==="
}

#------------------------------------------------------------------------------
# [옵션3] Surfshark VPN 확장만 설치
#------------------------------------------------------------------------------
function Option3-InstallSurfsharkVPN {
    Write-Host "`n[3] Surfshark VPN 확장만 설치"

    $surfsharkId = "ailoabdmgclmfmhdagmlohpjlbpffblp"

    # 기존 확장 프로그램 삭제하지 않도록 별도 함수 사용
    Set-ChromePolicyNoRemoveExtensions -ExtensionIds @($surfsharkId)

    Write-Host "`n=== Surfshark VPN 확장 설치 완료 (기존 확장 유지) ==="
}

#------------------------------------------------------------------------------
# [옵션4] 유용한 확장만 설치 (uBlock, Volume Master, FastForward, Surfshark VPN)
#------------------------------------------------------------------------------
function Option4-InstallUsefulExtensions {
    Write-Host "`n[4] 유용한 확장만 설치"

    $uBlockId      = "cjpalhdlnbpafiamejdnhcphjbkeiagm"
    $volumeMasterId = "jghecgabfgfdldnmbfkhmffcabddioke"
    $fastForwardId = "icallnadddjmdinamnolclfjanhfoafe"
    $surfsharkId   = "ailoabdmgclmfmhdagmlohpjlbpffblp"

    Set-ChromePolicyAndRemoveExtensions -ExtensionIds @(
        $uBlockId, 
        $volumeMasterId, 
        $fastForwardId,
        $surfsharkId
    )

    Write-Host "`n=== 유용한 확장 설치 완료 ==="
}

#------------------------------------------------------------------------------
# [옵션5] 마에스트로웹5 및 맘아이 무력화
#------------------------------------------------------------------------------
function Option5-MaestroWeb5MommyDisable {
    Write-Host "`n[5] 마에스트로웹5 및 맘아이 무력화"

    # 예시 프로세스명 (환경에 따라 수정)
    $targetProcNames = @("nfowjyxfd", "qukapttp", "MaestroWebAgent", "MaestroWebSvr")

    # 1) 이미 실행 중인 대상 프로세스 종료
    foreach ($name in $targetProcNames) {
        $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
        if ($procs) {
            foreach ($p in $procs) {
                try {
                    Write-Host "  -> 프로세스 종료 시도: $($p.Name) (PID: $($p.Id))"
                    Stop-Process -Id $p.Id -Force
                }
                catch {
                    Write-Warning "    종료 실패: $($_.Exception.Message)"
                }
            }
        }
        else {
            Write-Host "  -> 현재 실행 중 아님: $name"
        }
    }

    # 2) 재실행될 경우 즉시 종료 (WMI Event Subscription)
    Write-Host "`n  -> 프로세스 재실행 차단용 WMI 이벤트 구독 등록..."
    $global:ProcessNamesToBlock = $targetProcNames

    # 기존 구독 해제
    $existingSubs = Get-EventSubscriber | Where-Object { $_.SourceIdentifier -eq "BlockProcessStartTrace" }
    foreach ($sub in $existingSubs) {
        Unregister-Event -SubscriptionId $sub.SubscriptionId
    }

    $script:processBlockSubscription = Register-WmiEvent -Query "SELECT * FROM Win32_ProcessStartTrace" `
        -Action {
            param($sender, $eventArgs)

            $newProcName = $eventArgs.NewEvent.ProcessName
            $newProcId   = $eventArgs.NewEvent.ProcessID
            $procNameNoExt = $newProcName.Replace(".exe","")

            if ($global:ProcessNamesToBlock -contains $procNameNoExt) {
                try {
                    Stop-Process -Id $newProcId -Force
                    Write-Host "[Blocker] 프로세스 $newProcName(PID: $newProcId) 종료 완료"
                }
                catch {
                    Write-Warning "[Blocker] 프로세스 $newProcName 종료 실패: $($_.Exception.Message)"
                }
            }
        } `
        -SourceIdentifier "BlockProcessStartTrace"

    Write-Host "  -> 마에스트로웹5/맘아이 프로세스 재실행 차단이 활성화됨."
    Write-Host "     스크립트를 종료하지 않는 동안 즉시 차단이 계속됩니다."
    Write-Host "     (Enter 키를 누르면 이벤트 구독을 해제하고 메뉴로 돌아갑니다.)"

    Read-Host

    # 이벤트 구독 해제
    Unregister-Event -SourceIdentifier "BlockProcessStartTrace"
    Write-Host "  -> 재실행 차단용 이벤트 구독 해제 완료."
}

#------------------------------------------------------------------------------
# [옵션6] 사지방 해제기 설치 (CCUpdater)
#------------------------------------------------------------------------------
function Option6-InstallCCUpdater {
    Write-Host "`n[6] 사지방 해제기 설치 (CCUpdater)"
    Run-CCUpdaterProcess
}

#------------------------------------------------------------------------------
# [옵션7] Proton VPN 설치
#------------------------------------------------------------------------------
function Option7-InstallProtonVPN {
    Write-Host "`n[7] Proton VPN 설치"
    Install-ProtonVPN
}

#------------------------------------------------------------------------------
#             메인 루프 (메뉴 표시 후 사용자 입력)
#------------------------------------------------------------------------------
do {
    Show-Menu
    $choice = Read-Host "`n선택"
    
    switch ($choice) {
        "1" {
            Option1-IntegrateInstall
            Pause
        }
        "2" {
            Option2-ThoriumInstall
            Pause
        }
        "3" {
            Option3-InstallSurfsharkVPN
            Pause
        }
        "4" {
            Option4-InstallUsefulExtensions
            Pause
        }
        "5" {
            Option5-MaestroWeb5MommyDisable
            Pause
        }
        "6" {
            Option6-InstallCCUpdater
            Pause
        }
        "7" {
            Option7-InstallProtonVPN
            Pause
        }
        "Q" {
            Write-Host "`n스크립트를 종료합니다."
            return
        }
        default {
            Write-Host "`n잘못된 선택입니다. 다시 선택해주세요."
        }
    }
    
    Write-Host "`n계속하려면 아무 키나 누르세요..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
} while ($true)