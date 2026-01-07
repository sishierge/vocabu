Set-Location 'D:\nixiang_app\vocabu'

# 删除旧的便携版目录
if (Test-Path 'installer_output\Vocabu_Portable') {
    Remove-Item -Recurse -Force 'installer_output\Vocabu_Portable'
}

# 创建目录
New-Item -ItemType Directory -Path 'installer_output\Vocabu_Portable' -Force
New-Item -ItemType Directory -Path 'installer_output\Vocabu_Portable\plugins' -Force

# 复制主程序文件
Copy-Item -Path 'build\windows\x64\runner\Release\*' -Destination 'installer_output\Vocabu_Portable' -Recurse -Force

# 复制插件
Copy-Item -Path 'installer_output\extracted\DanmuOverlay.exe' -Destination 'installer_output\Vocabu_Portable\plugins\' -Force
Copy-Item -Path 'installer_output\extracted\CarouselOverlay.exe' -Destination 'installer_output\Vocabu_Portable\plugins\' -Force
Copy-Item -Path 'installer_output\extracted\StickyOverlay.exe' -Destination 'installer_output\Vocabu_Portable\plugins\' -Force
Get-ChildItem 'installer_output\extracted\*.dll' | ForEach-Object { Copy-Item $_.FullName -Destination 'installer_output\Vocabu_Portable\plugins\' -Force }
Get-ChildItem 'installer_output\extracted\*.json' | ForEach-Object { Copy-Item $_.FullName -Destination 'installer_output\Vocabu_Portable\plugins\' -Force }

# 删除不需要的用户数据文件
Remove-Item 'installer_output\Vocabu_Portable\data\flutter_assets\assets\wordmomo.db' -Force -ErrorAction SilentlyContinue

# 创建压缩包
$zipPath = 'installer_output\Vocabu_1.0.0.zip'
if (Test-Path $zipPath) {
    Remove-Item $zipPath
}
Compress-Archive -Path 'installer_output\Vocabu_Portable\*' -DestinationPath $zipPath -Force

# 显示结果
Write-Host "安装包已生成!"
$file = Get-Item $zipPath
Write-Host "文件: $($file.Name)"
Write-Host "大小: $([math]::Round($file.Length/1MB, 2)) MB"
Write-Host "路径: $($file.FullName)"
