$START_DIR = "$(get-location)"
$product_version = $Env:MTX_PRODUCT_VERSION
if (!"$product_version") {
    $product_version = "9.9.9.9"
}

$build_number = $Env:MTX_BUILD_NUMBER
if (!"$build_number") {
    $build_number = "999"
}

#& $START_DIR\packaging\vc\VC_redist.x64.exe /q

Get-Command python.exe | Select-Object -ExpandProperty Definition

#Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -like "*Python*"} | Remove-WmiObject

#Start-Sleep -Seconds 20
#if( Test-Path $START_DIR\python311 ) { Remove-Item $START_DIR\python311 -Recurse -Force }
Remove-Item -Path Env:PYTHONPATH -Force -ErrorAction Ignore
Remove-Item -Path Env:PYTHONHOME -Force -ErrorAction Ignore

#$app = Get-WmiObject -Class Win32_Product | Where-Object {
#    $_.Name -match "Python*"
#}
#$app.Uninstall()

#if ( $LastExitCode ) { exit 1 }
#Restart-Computer -Force

#Start-Sleep -Seconds 60
#Set-Location -Path $START_DIR
#if( Test-Path $START_DIR\python311 ) { Remove-Item $START_DIR\python311 -Recurse -Force }
#Set-Location -Path $START_DIR
#New-Item -ItemType directory -Path .\python311
Set-Location -Path "${START_DIR}\packaging\python3"
##& .\python-3.10.9-amd64.exe /quiet TargetDir=${START_DIR}\python311 InstallAllUsers=1 PrependPath=1 Include_test=0 Include_launcher=0 /log "%WINDIR%\Temp\python311-Install.log"
& .\python-3.10.9-amd64.exe /quiet TargetDir=${START_DIR}\python311 InstallAllUsers=1 PrependPath=1 Include_test=0 Include_launcher=0
if ( $LastExitCode ) { exit 1 }
Start-Sleep -Seconds 240
Set-Location -Path "${START_DIR}"
if (-Not (Test-Path "${START_DIR}\python311")) {
    Write-Host "Python Not Installed"
    exit 1
} else {
    Write-Host "Python Installed"
}

# Create an exe from the python script
$Env:PYTHONHOME="${START_DIR}\python311"
#$Env:PYTHONPATH="${START_DIR}\python311\Lib;${START_DIR}\python311\Lib\site-packages;${START_DIR}\python311\Scripts;${START_DIR}\python311"
$PYTHON_AMD64 = "${START_DIR}\python311\python.exe"
$PIP_AMD64 = "${START_DIR}\python311\Scripts\pip.exe"
$PYINST_AMD64 = "${START_DIR}\python311\Scripts\pyinstaller.exe"

Set-Location -Path $START_DIR
#if( Test-Path .\pywin32amd64 ) { Remove-Item .\pywin32amd64 -Recurse -Force }
#New-Item -ItemType directory -Path .\pywin32amd64
#& 7z x -y -opywin32amd64 .\packaging\pywin32\pywin32-305.win-amd64-py3.11.exe
#& 7z x -y -opywin32amd64 .\packaging\pywin32\pywin32-304.win-amd64-py3.10.exe

#Copy-Item "${START_DIR}\pywin32amd64\PLATLIB\*"  "$(get-location)\python311\Lib\site-packages" -Recurse -Force
#Copy-Item "${START_DIR}\pywin32amd64\SCRIPTS\*"  "$(get-location)\python311\Scripts" -Recurse -Force
#Set-Location -Path "${START_DIR}\python311\Scripts"
#& $PYTHON_AMD64 pywin32_postinstall.py "-install"

# Add FIPS requirements

# Add ssl, _ssl, and _hashlib which point to morpheus project OPENSSL
Copy-Item "${START_DIR}\packaging\python3\windows\*.pyd" "${START_DIR}\python311\DLLs" -Recurse -Force
Copy-Item "${START_DIR}\packaging\python3\windows\*.dll" "${START_DIR}\python311\DLLs" -Recurse -Force
Copy-Item "${START_DIR}\packaging\python3\windows\*.cnf" "${START_DIR}\python311\DLLs" -Recurse -Force
Copy-Item "${START_DIR}\packaging\python3\windows\ssl.py" "${START_DIR}\python311\Lib" -Recurse -Force
Write-Host "OpenSSL 3 Copied"

Set-Location -Path $START_DIR
& ${START_DIR}\python311\python -m venv venv
& venv\Scripts\activate
#& $PYTHON_AMD64 -m ensurepip

Copy-Item "${START_DIR}\packaging\python3\windows\print_ssl_version.py"  "$(get-location)" -Recurse -Force
& $PYTHON_AMD64 print_ssl_version.py

Function InstallPythonModule($python, $name, $version) {
    Set-Location -Path "${START_DIR}"
    if( Test-Path .\${name} ) { Remove-Item .\${name} -Recurse -Force }
    New-Item -ItemType directory -Path "${START_DIR}\${name}"
    & 7z x -y "-o${name}" .\packaging\ext\${name}-${version}.tar.gz
    if (Test-Path .\${name}\dist ) {
        & 7z x -y "-o${name}" "${START_DIR}\${name}\dist\${name}-${version}.tar"
    }
    else {
        & 7z x -y "-o${name}" "${START_DIR}\${name}\${name}-${version}.tar"
    }
    Set-Location -Path "${START_DIR}\${name}\${name}-${version}"
    & $python setup.py install
    Set-Location -Path "${START_DIR}"
}

Function InstallPyInstallerModule($python, $name, $version) {
    Set-Location -Path "${START_DIR}"
    if( Test-Path .\${name} ) { Remove-Item .\${name} -Recurse -Force }
    New-Item -ItemType directory -Path "${START_DIR}\${name}"
    & 7z x -y "-o${name}" .\packaging\ext\${name}-${version}.tar.gz
    & 7z x -y "-o${name}" "${START_DIR}\${name}\dist\${name}-${version}.tar"
    Set-Location -Path "${START_DIR}\${name}\${name}-${version}\bootloader"
    & $python ./waf distclean all
    Set-Location -Path "${START_DIR}\${name}\${name}-${version}"
    & $python setup.py install
    Set-Location -Path "${START_DIR}"
}

Function InstallPythonModuleZip($python, $name, $version) {
    Set-Location -Path "${START_DIR}"
    if( Test-Path .\${name} ) { Remove-Item .\${name} -Recurse -Force }
    New-Item -ItemType directory -Path "${START_DIR}\${name}"
    & 7z x -y "-o${name}" .\packaging\ext\${name}-${version}.zip
    Set-Location -Path "${START_DIR}\${name}\${name}-${version}"
    & $python setup.py install
    Set-Location -Path "${START_DIR}"
}

Function InstallPythonModuleWheel($pip, $name, $version) {
    Set-Location -Path "${START_DIR}\packaging\ext"
    & $pip install ${name}_wheel-${version}-py3-none-any.whl
    Set-Location -Path "${START_DIR}"
}

Function InstallPythonModuleBin($python, $name, $version) {
    Set-Location -Path "${START_DIR}"
    if( Test-Path .\${name} ) { Remove-Item .\${name} -Recurse -Force }
    New-Item -ItemType directory -Path "${START_DIR}\${name}"
    & 7z x -y "-o${name}" .\packaging\ext\${name}-${version}.exe
    Set-Location -Path "${START_DIR}\${name}"
    Copy-Item "${START_DIR}\${name}\PLATLIB\*"  "${START_DIR}\python311\Lib\site-packages" -Recurse -Force
    Set-Location -Path "${START_DIR}"
}

Function InstallUPX() {
    Set-Location -Path "${START_DIR}"
    if( Test-Path .\upx ) { Remove-Item .\upx -Recurse -Force }
    & 7z e -y "-oupx" .\packaging\ext\upx394w.zip
    Set-Location -Path "${START_DIR}\upx"
    Copy-Item "${START_DIR}\upx\upx.exe"  "${START_DIR}\src" -Recurse -Force
    Set-Location -Path "${START_DIR}"
}

InstallPythonModule "$PYTHON_AMD64" "setuptools" "65.6.3"
InstallPythonModule "$PYTHON_AMD64" "pip" "22.3.1"
InstallPythonModule "$PYTHON_AMD64" "wheel" "0.38.4"
InstallPythonModule "$PYTHON_AMD64" "jsonpointer" "2.3"
InstallPythonModule "$PYTHON_AMD64" "python-dotenv" "0.21.0"
InstallPythonModule "$PYTHON_AMD64" "six" "1.16.0"
InstallPythonModule "$PYTHON_AMD64" "ply" "3.11"
InstallPythonModule "$PYTHON_AMD64" "future" "0.18.2"
InstallPythonModule "$PYTHON_AMD64" "altgraph" "0.17.3"
InstallPythonModule "$PYTHON_AMD64" "decorator" "5.1.1"
InstallPythonModule "$PYTHON_AMD64" "jsonpatch" "1.32"
InstallPythonModule "$PYTHON_AMD64" "jsonpath-rw" "1.4.0"
InstallPythonModule "$PYTHON_AMD64" "jsondiff" "2.0.0"
InstallPythonModule "$PYTHON_AMD64" "pyaes" "1.6.1"
InstallPythonModule "$PYTHON_AMD64" "urllib3" "1.26.12"
Set-Location -Path "${START_DIR}\packaging\ext"
& $PIP_AMD64 install colorama-0.4.4.tar.gz
& $PIP_AMD64 install tabulate-0.8.9.tar.gz
Set-Location -Path "${START_DIR}"
#InstallPythonModule "$PYTHON_AMD64" "colorama" "0.4.6"
#InstallPythonModule "$PYTHON_AMD64" "tabulate" "0.9.0"
InstallPythonModule "$PYTHON_AMD64" "wcwidth" "0.2.5"
InstallPythonModule "$PYTHON_AMD64" "pefile" "2022.5.30"
InstallPythonModule "$PYTHON_AMD64" "prompt_toolkit" "3.0.36"
InstallPythonModule "$PYTHON_AMD64" "pywin32-ctypes" "0.2.0"
InstallPythonModule "$PYTHON_AMD64" "certifi" "2022.12.7"
InstallPythonModule "$PYTHON_AMD64" "idna" "3.4"
InstallPythonModule "$PYTHON_AMD64" "requests" "2.28.1"
InstallPythonModule "$PYTHON_AMD64" "pypiwin32" "223"
Set-Location -Path "${START_DIR}\packaging\ext"
& $PIP_AMD64 install pywin32-305-cp310-cp310-win_amd64.whl
Set-Location -Path "${START_DIR}"
InstallPythonModule "$PYTHON_AMD64" "pyinstaller-hooks-contrib" "2022.10"
#InstallPythonModule "$PYTHON_AMD64" "pyinstaller" "5.7.0"
Set-Location -Path "${START_DIR}\packaging\ext"
& $PIP_AMD64 install pyinstaller-5.7.0.tar.gz
Set-Location -Path "${START_DIR}"

Copy-Item "$Env:MTX_STAGING_PATH\externals\*.zip" "${START_DIR}\packaging\ext"
InstallPythonModuleZip "$PYTHON_AMD64" "python-ilorest-library" "$Env:MX_ILOREST_LIB_VERSION"
Set-Location -Path $START_DIR

Function CreateMSI($python, $pyinstaller, $pythondir, $arch) {
    Set-Location -Path "${START_DIR}"
    if( Test-Path $START_DIR\dist ) { Remove-Item $START_DIR\dist -Recurse -Force }
    if( Test-Path $START_DIR\build ) { Remove-Item $START_DIR\build -Recurse -Force }
    Set-Location -Path $START_DIR

    $DOUBLE_START_DIR =  $START_DIR.replace("\", "\\")
    $DOUBLE_PYTHONDIR =  $pythondir.replace("\", "\\")

    cat win32\rdmc-pyinstaller.spec.in | %{$_ -replace '\$pwd',"${DOUBLE_START_DIR}" } | %{$_ -replace '\$pythondir',"${DOUBLE_PYTHONDIR}" } > rdmc-pyinstaller.spec

    # kill the BOM (stupid powershell)
    $MyFile = Get-Content "${START_DIR}\rdmc-pyinstaller.spec"
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)
    [System.IO.File]::WriteAllLines("${START_DIR}\rdmc-pyinstaller.spec", $MyFile, $Utf8NoBomEncoding)

    Set-Location -Path "${START_DIR}\src"
    #& $python "${START_DIR}\PyInstaller\PyInstaller-3.6\pyinstaller.py" --onefile $START_DIR\rdmc-pyinstaller.spec
    & $pyinstaller $START_DIR\rdmc-pyinstaller.spec
    perl C:\ABSbuild\CodeSigning\SignFile.pl "${START_DIR}\src\dist\ilorest.exe"
    Copy-Item "${START_DIR}\src\dist\ilorest.exe" "${START_DIR}\ilorest.exe"
    Copy-Item "$Env:MTX_STAGING_PATH\externals\*.dll" "${START_DIR}\src\dist\"
    Copy-Item "${START_DIR}\packaging\packages\*.dll" "${START_DIR}\src\dist\"
    Copy-Item "${START_DIR}\rdmc-windows.conf" "${START_DIR}\src\dist\redfish.conf"
    Copy-Item "${START_DIR}\src\dist" "${START_DIR}" -Recurse -Force

    Set-Location -Path "${START_DIR}"
    $product_version

    cat win32\rdmc.${arch}.wxs | %{$_ -replace '\$product_version',"${product_version}" } > rdmc.wxs
    & c:\ABSbuild\WiX36\candle.exe "-dsrcFolder=$(get-location)" rdmc.wxs
    & c:\ABSbuild\WiX36\light.exe -b $(get-location) rdmc.wixobj -ext WixUIExtension  -out "ilorest-${product_version}-${build_number}.${arch}.msi"

    if ("$Env:MTX_COLLECTION_PATH") {
        & perl C:\ABSbuild\CodeSigning\SignFile.pl "ilorest-${product_version}-${build_number}.${arch}.msi"
        Copy-Item "ilorest-${product_version}-${build_number}.${arch}.msi" "$Env:MTX_COLLECTION_PATH"
    }
    Set-Location -Path "${START_DIR}"
}

Set-Location -Path "${START_DIR}"
#Copy-Item "${START_DIR}\pywin32amd64\PLATLIB\pywin32_system32\*" .
CreateMSI "$PYTHON_AMD64" "$PYINST_AMD64" "${START_DIR}\python311" "x86_64"

#Uninstall Python finally
$app = Get-WmiObject -Class Win32_Product | Where-Object {
    $_.Name -match "Python*"
}
$app.Uninstall()
