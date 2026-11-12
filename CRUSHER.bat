@echo off
setlocal DisableDelayedExpansion
title CRUSH - Batch Media Compressor

:: ============================================================================
:: 1. AUTO-ELEVATE TO ADMINISTRATOR (Single-Window Hand-off)
:: ============================================================================
net session >nul 2>&1
if errorlevel 1 goto :ELEVATE
goto :INIT

:ELEVATE
echo Requesting Administrator privileges...
set "CRUSH_SELF=%~f0"
powershell -NoProfile -Command "try { Start-Process -FilePath $env:CRUSH_SELF -Verb RunAs -ErrorAction Stop; exit 0 } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
    echo.
    echo ============================================================================
    echo [ERROR] Administrator privileges were declined.
    echo Please click "Yes" on the UAC prompt, or right-click "%~nx0"
    echo and select "Run as administrator".
    echo ============================================================================
    pause
    exit /b 1
)
:: Immediately close this non-admin launcher window once the elevated window opens
exit

:INIT
:: Lock working directory to the folder containing this .bat file
cd /d "%~dp0"

:: ============================================================================
:: 2. LOCATE OR AUTO-DOWNLOAD FFMPEG.EXE
:: ============================================================================
set "FFMPEG_CMD="
if exist "%~dp0ffmpeg.exe" set "FFMPEG_CMD=%~dp0ffmpeg.exe"
if not defined FFMPEG_CMD (
    where ffmpeg >nul 2>&1 && set "FFMPEG_CMD=ffmpeg"
)
if not defined FFMPEG_CMD (
    if exist "C:\ffmpeg\bin\ffmpeg.exe" set "FFMPEG_CMD=C:\ffmpeg\bin\ffmpeg.exe"
)
if not defined FFMPEG_CMD (
    for /f "delims=" %%F in ('dir /b /s "%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg*\ffmpeg.exe" 2^>nul') do set "FFMPEG_CMD=%%F"
)

if not defined FFMPEG_CMD (
    echo ============================================================================
    echo [SETUP] FFmpeg.exe was not found on your computer.
    echo Automatically downloading FFmpeg from gyan.dev ^(one-time setup^)...
    echo ============================================================================
    echo.
    call :DOWNLOAD_FFMPEG
)

if not defined FFMPEG_CMD (
    echo.
    echo ============================================================================
    echo [ERROR] Automatic FFmpeg download failed. Please check your internet
    echo connection or manually place ffmpeg.exe into this folder:
    echo "%~dp0"
    echo ============================================================================
    pause
    exit /b 1
)

:: ============================================================================
:: 3. INTERACTIVE PRESET SELECTION MENU
:: ============================================================================
:MENU
cls
echo ============================================================================
echo                       CRUSH - Batch Media Compressor
echo            100%% Local GPU Hardware Video ^& Image Compression
echo ============================================================================
echo.
echo Choose a Compression Preset:
echo.
echo   [1] Super Compress    : 10%%-20%% of original size (lossy)
echo   [2] Balanced Compress : 50%%-60%% of original size (lossy - Recommended)
echo   [3] Light Compress    : 60%%-85%% of original size (lossy)
echo   [4] Lossless Compress : 85%%-95%% of original size (lossless)
echo.
echo ============================================================================
echo TIP: To stop compression at any time, simply close this command window.
echo Avoid running VRAM-heavy applications alongside CRUSH while encoding.
echo ============================================================================
echo.
set "PRESET_CHOICE="
set /p "PRESET_CHOICE=Select a preset (1-4) [Default: 2]: "

:: Sanitize input to prevent batch syntax crashes on quotes or spaces
if defined PRESET_CHOICE (
    set "PRESET_CHOICE=%PRESET_CHOICE:"=%"
    set "PRESET_CHOICE=%PRESET_CHOICE: =%"
)
if not defined PRESET_CHOICE set "PRESET_CHOICE=2"

if "%PRESET_CHOICE%"=="1" (
    set "PRESET_NAME=Super Compress [10%%-20%%]"
    set "TARG_MULT=0.14"
    set "MAX_MULT=0.19"
    set "AUDIO_MODE=AAC"
    set "AUDIO_KBPS=96"
    set "IMG_Q_JPG=18"
    set "IMG_Q_WEBP=35"
    set "PNG_COLORS=64"
) else if "%PRESET_CHOICE%"=="2" (
    set "PRESET_NAME=Balanced Compress [50%%-60%%]"
    set "TARG_MULT=0.53"
    set "MAX_MULT=0.59"
    set "AUDIO_MODE=COPY"
    set "AUDIO_KBPS=160"
    set "IMG_Q_JPG=7"
    set "IMG_Q_WEBP=70"
    set "PNG_COLORS=128"
) else if "%PRESET_CHOICE%"=="3" (
    set "PRESET_NAME=Light Compress [60%%-85%%]"
    set "TARG_MULT=0.72"
    set "MAX_MULT=0.83"
    set "AUDIO_MODE=COPY"
    set "AUDIO_KBPS=160"
    set "IMG_Q_JPG=4"
    set "IMG_Q_WEBP=82"
    set "PNG_COLORS=256"
) else if "%PRESET_CHOICE%"=="4" (
    set "PRESET_NAME=Lossless Compress [85%%-95%%]"
    set "TARG_MULT=0.88"
    set "MAX_MULT=0.94"
    set "AUDIO_MODE=COPY"
    set "AUDIO_KBPS=192"
    set "IMG_Q_JPG=2"
    set "IMG_Q_WEBP=95"
    set "PNG_COLORS=0"
) else (
    echo.
    echo [INVALID] Please enter 1, 2, 3, or 4.
    timeout /t 2 >nul
    goto :MENU
)

if not exist "compressed" mkdir "compressed"

echo.
echo Starting CRUSH with preset: "%PRESET_NAME%"
echo Output folder: "%~dp0compressed"

:: ============================================================================
:: 4. PROCESS VIDEOS & IMAGES SAFELY (Protects '!' and '()' in filenames)
:: ============================================================================
set "FOUND_MEDIA=0"

for %%f in (*.mp4 *.mov *.m4v *.mkv *.avi *.webm) do (
    set "FOUND_MEDIA=1"
    call :ENCODE_VIDEO "%%~f"
)

for %%i in (*.jpg *.jpeg *.png *.webp *.bmp) do (
    set "FOUND_MEDIA=1"
    call :COMPRESS_IMAGE "%%~i"
)

echo.
echo ============================================================================
if "%FOUND_MEDIA%"=="0" (
    echo [NOTICE] No supported video or image files found in this directory.
) else (
    echo Finished! All media processed using "%PRESET_NAME%".
    echo Compressed files are saved in the "compressed" folder.
)
echo ============================================================================
pause
exit /b 0

:: ============================================================================
:: SUBROUTINE: :DOWNLOAD_FFMPEG
:: Downloads ffmpeg-release-essentials.zip and extracts only ffmpeg.exe locally
:: ============================================================================
:DOWNLOAD_FFMPEG
set "FF_ZIP=%TEMP%\crush_ffmpeg_essentials.zip"
set "FF_DEST=%~dp0ffmpeg.exe"
set "FF_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"

if exist "%FF_ZIP%" del /q "%FF_ZIP%"

:: Use built-in Windows curl.exe for full-speed download, fallback to PowerShell
where curl.exe >nul 2>&1
if not errorlevel 1 (
    curl.exe -fL --progress-bar "%FF_URL%" -o "%FF_ZIP%"
) else (
    powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object System.Net.WebClient).DownloadFile($env:FF_URL, $env:FF_ZIP)"
)

if not exist "%FF_ZIP%" exit /b 1

echo.
echo Extracting ffmpeg.exe...
powershell -NoProfile -Command "try { Add-Type -AssemblyName System.IO.Compression.FileSystem; $z = [System.IO.Compression.ZipFile]::OpenRead($env:FF_ZIP); $e = $z.Entries | Where-Object { $_.Name -ieq 'ffmpeg.exe' } | Select-Object -First 1; if (-not $e) { throw 'ffmpeg.exe not found in archive' }; [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $env:FF_DEST, $true); $z.Dispose(); exit 0 } catch { if ($z) { $z.Dispose() }; exit 1 }"

if exist "%FF_ZIP%" del /q "%FF_ZIP%"

if exist "%FF_DEST%" (
    set "FFMPEG_CMD=%FF_DEST%"
    echo [SUCCESS] FFmpeg.exe installed to "%FF_DEST%".
    timeout /t 2 >nul
    exit /b 0
)
exit /b 1

:: ============================================================================
:: SUBROUTINE: :ENCODE_VIDEO
:: Max-speed NVENC P1 zero-copy pipeline (10-30x GPU speed across all presets)
:: ============================================================================
:ENCODE_VIDEO
set "IN_FILE=%~1"
set "ORIG_SIZE=%~z1"
set "TMP_OUT=compressed\_crush_tmp.mp4"
set "FINAL_OUT=compressed\%~n1.mp4"
set "ORIG_COPY=compressed\%~nx1"

:: Prevent filename collision if both foo.mp4 and foo.mov exist in the same folder
if /i not "%~x1"==".mp4" (
    if exist "%~n1.mp4" set "FINAL_OUT=compressed\%~n1_%~x1.mp4"
)
set "FINAL_OUT=%FINAL_OUT:.mp4.mp4=.mp4%"
set "FINAL_OUT=%FINAL_OUT:_.=_%"

if exist "%TMP_OUT%" del /q "%TMP_OUT%"

set "TARG_KBPS=4000"
set "MAX_KBPS=5000"
set "BUF_KBPS=10000"

:: Fast duration & bitrate probe (avoids PowerShell Out-String 80-col line wrap)
for /f "tokens=1,2,3 delims=," %%A in ('powershell -NoProfile -Command "$f = Get-Item -LiteralPath $env:IN_FILE; $out = (& $env:FFMPEG_CMD -hide_banner -i $f.FullName 2>&1 | ForEach-Object { $_.ToString() }) -join \"`n\"; $sec = 0; if ($out -match 'Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)') { $sec = ([int]$matches[1]*3600)+([int]$matches[2]*60)+[double]::Parse($matches[3], [System.Globalization.CultureInfo]::InvariantCulture) }; if ($sec -le 0.1) { '4000,5000,10000'; exit }; $kb = ($f.Length * 8) / ($sec * 1000); $akb = [int]$env:AUDIO_KBPS; $tm = [double]::Parse($env:TARG_MULT, [System.Globalization.CultureInfo]::InvariantCulture); $mm = [double]::Parse($env:MAX_MULT, [System.Globalization.CultureInfo]::InvariantCulture); $t = [math]::Max(80, [int](($kb * $tm) - $akb)); $m = [math]::Max($t + 50, [int](($kb * $mm) - $akb)); $b = $m * 2; '{0},{1},{2}' -f $t,$m,$b"') do (
    set "TARG_KBPS=%%A"
    set "MAX_KBPS=%%B"
    set "BUF_KBPS=%%C"
)

echo.
echo [VIDEO] Compressing "%~nx1" [%PRESET_NAME%] [Target: %TARG_KBPS%k / Max: %MAX_KBPS%k]...

:: Select zero-overhead audio copy (Presets 2-4) or fast AAC (Preset 1)
if "%AUDIO_MODE%"=="COPY" (
    set "AUD_ARGS=-c:a copy"
) else (
    set "AUD_ARGS=-c:a aac -aac_coder fast -b:a %AUDIO_KBPS%k"
)

:: Path 1: Zero-Copy CUDA VRAM + HEVC NVENC P1 (Supports 8-bit & 10-bit HDR at 10-30x speed)
"%FFMPEG_CMD%" -y -hide_banner -hwaccel cuda -hwaccel_output_format cuda -extra_hw_frames 8 -threads 4 -i "%IN_FILE%" ^
    -map 0:v:0 -map 0:a? -dn -sn ^
    -c:v hevc_nvenc -preset p1 -rc vbr -multipass disabled ^
    -b:v %TARG_KBPS%k -maxrate %MAX_KBPS%k -bufsize %BUF_KBPS%k ^
    -tag:v hvc1 -movflags +faststart ^
    %AUD_ARGS% -map_metadata 0 "%TMP_OUT%"

:: Path 2: CUDA Decode + Even-Dimension Scale + H.264 NVENC P1 (Handles odd dimensions / incompatible audio)
if errorlevel 1 (
    echo [NOTICE] Retrying "%~nx1" with GPU H.264 P1 compatibility pipeline...
    "%FFMPEG_CMD%" -y -hide_banner -hwaccel cuda -threads 4 -i "%IN_FILE%" ^
        -map 0:v:0 -map 0:a? -dn -sn ^
        -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p" ^
        -c:v h264_nvenc -preset p1 -rc vbr -multipass disabled ^
        -b:v %TARG_KBPS%k -maxrate %MAX_KBPS%k -bufsize %BUF_KBPS%k ^
        -movflags +faststart ^
        -c:a aac -aac_coder fast -b:a %AUDIO_KBPS%k -map_metadata 0 "%TMP_OUT%"
)

:: Path 3: Ultra-fast CPU Fallback (if no NVIDIA GPU is available or unsupported source codec)
if errorlevel 1 (
    echo [NOTICE] Retrying "%~nx1" with Ultrafast CPU pipeline...
    "%FFMPEG_CMD%" -y -hide_banner -i "%IN_FILE%" ^
        -map 0:v:0 -map 0:a? -dn -sn ^
        -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p" ^
        -c:v libx264 -preset ultrafast ^
        -b:v %TARG_KBPS%k -maxrate %MAX_KBPS%k -bufsize %BUF_KBPS%k ^
        -movflags +faststart ^
        -c:a aac -aac_coder fast -b:a %AUDIO_KBPS%k -map_metadata 0 "%TMP_OUT%"
)

if errorlevel 1 (
    echo [ERROR] Encoding failed for "%~nx1". Removing incomplete output...
    if exist "%TMP_OUT%" del /q "%TMP_OUT%"
    exit /b 1
)

call :FINALIZE_OUTPUT "%IN_FILE%" "%TMP_OUT%" "%FINAL_OUT%" "%ORIG_COPY%" "%ORIG_SIZE%"
exit /b 0

:: ============================================================================
:: SUBROUTINE: :COMPRESS_IMAGE
:: High-speed local FFmpeg image compression (JPG, PNG, WEBP, BMP)
:: ============================================================================
:COMPRESS_IMAGE
set "IN_IMG=%~1"
set "EXT=%~x1"
set "ORIG_SIZE=%~z1"
set "TMP_IMG=compressed\_crush_tmp%~x1"
set "FINAL_IMG=compressed\%~nx1"
set "ORIG_COPY=compressed\%~nx1"

:: Raw .bmp cannot shrink if re-saved as uncompressed .bmp; output as .jpg (Presets 1-3) or .png (Preset 4)
if /i "%EXT%"==".bmp" (
    if "%PRESET_CHOICE%"=="4" (
        set "TMP_IMG=compressed\_crush_tmp.png"
        set "FINAL_IMG=compressed\%~n1.png"
    ) else (
        set "TMP_IMG=compressed\_crush_tmp.jpg"
        set "FINAL_IMG=compressed\%~n1.jpg"
    )
)

if exist "%TMP_IMG%" del /q "%TMP_IMG%"

echo.
echo [IMAGE] Compressing "%~nx1" [%PRESET_NAME%]...

if /i "%EXT%"==".png" (
    if "%PNG_COLORS%"=="0" (
        "%FFMPEG_CMD%" -y -hide_banner -loglevel error -i "%IN_IMG%" -compression_level 9 "%TMP_IMG%"
    ) else (
        "%FFMPEG_CMD%" -y -hide_banner -loglevel error -i "%IN_IMG%" -lavfi "split[s0][s1];[s0]palettegen=max_colors=%PNG_COLORS%[p];[s1][p]paletteuse=dither=bayer" -compression_level 9 "%TMP_IMG%"
    )
) else if /i "%EXT%"==".webp" (
    if "%PRESET_CHOICE%"=="4" (
        "%FFMPEG_CMD%" -y -hide_banner -loglevel error -i "%IN_IMG%" -lossless 1 -compression_level 4 "%TMP_IMG%"
    ) else (
        "%FFMPEG_CMD%" -y -hide_banner -loglevel error -i "%IN_IMG%" -lossless 0 -q:v %IMG_Q_WEBP% -compression_level 4 "%TMP_IMG%"
    )
) else if /i "%EXT%"==".bmp" (
    if "%PRESET_CHOICE%"=="4" (
        "%FFMPEG_CMD%" -y -hide_banner -loglevel error -i "%IN_IMG%" -compression_level 9 "%TMP_IMG%"
    ) else (
        "%FFMPEG_CMD%" -y -hide_banner -loglevel error -i "%IN_IMG%" -q:v %IMG_Q_JPG% "%TMP_IMG%"
    )
) else (
    "%FFMPEG_CMD%" -y -hide_banner -loglevel error -i "%IN_IMG%" -q:v %IMG_Q_JPG% "%TMP_IMG%"
)

if errorlevel 1 (
    echo [ERROR] Image compression failed for "%~nx1".
    if exist "%TMP_IMG%" del /q "%TMP_IMG%"
    exit /b 1
)

call :FINALIZE_OUTPUT "%IN_IMG%" "%TMP_IMG%" "%FINAL_IMG%" "%ORIG_COPY%" "%ORIG_SIZE%"
exit /b 0

:: ============================================================================
:: SUBROUTINE: :FINALIZE_OUTPUT
:: Atomic temp-file swap + 64-Bit Safe Size Guard (bypasses 2 GB batch limit)
:: ============================================================================
:FINALIZE_OUTPUT
set "CHK_IN=%~1"
set "CHK_TMP=%~2"
set "CHK_FINAL=%~3"
set "CHK_COPY=%~4"
set "CHK_ORIG_SIZE=%~5"
set "NEW_SIZE=0"

if not exist "%CHK_TMP%" exit /b 1
for %%B in ("%CHK_TMP%") do set "NEW_SIZE=%%~zB"
if "%NEW_SIZE%"=="0" (
    echo [ERROR] Output file is 0 bytes for "%~nx1". Removing broken file...
    del /q "%CHK_TMP%"
    exit /b 1
)

set "PAD_ORIG=00000000000000000000%CHK_ORIG_SIZE%"
set "PAD_NEW=00000000000000000000%NEW_SIZE%"
set "PAD_ORIG=%PAD_ORIG:~-20%"
set "PAD_NEW=%PAD_NEW:~-20%"

if "%PAD_NEW%" GEQ "%PAD_ORIG%" (
    echo [SKIPPED] "%~nx1" did not shrink ^(%CHK_ORIG_SIZE% bytes vs %NEW_SIZE% bytes^).
    echo Keeping original file in "compressed" folder...
    del /q "%CHK_TMP%"
    copy /y "%CHK_IN%" "%CHK_COPY%" >nul
) else (
    move /y "%CHK_TMP%" "%CHK_FINAL%" >nul
)
exit /b 0