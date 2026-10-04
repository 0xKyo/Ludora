$aseprite = "E:\SteamLibrary\steamapps\common\Aseprite\Aseprite.exe"

$sourceDir = "Art/Source"
$outputDir = "Art/Generated"

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

Get-ChildItem $sourceDir -Filter *.aseprite -Recurse | ForEach-Object {
    $inputFile = $_.FullName
    $outputFile = Join-Path $outputDir ($_.BaseName + ".png")

    Write-Host "Exporting $inputFile -> $outputFile"

    & $aseprite `
        -b $inputFile `
        --save-as $outputFile
}