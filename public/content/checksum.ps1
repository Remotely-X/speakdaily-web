$Date = Read-Host "Escribe la fecha (YYYY-MM-DD)"

if ($Date -notmatch '^\d{4}-\d{2}-\d{2}$') {
    Write-Host "Fecha inválida. Usa este formato: 2026-05-03" -ForegroundColor Red
    exit 1
}

$JsonPath = Join-Path $PSScriptRoot "$Date.json"

if (-not (Test-Path $JsonPath)) {
    Write-Host "No existe el archivo: $JsonPath" -ForegroundColor Red
    exit 1
}

$pythonCode = @'
import json
import hashlib
import sys
from pathlib import Path

def canonicalize(value):
    if isinstance(value, dict):
        return {k: canonicalize(value[k]) for k in sorted(value.keys())}
    if isinstance(value, list):
        return [canonicalize(item) for item in value]
    return value

path = Path(sys.argv[1])

data = json.loads(path.read_text(encoding="utf-8"))

normalized = dict(data)
normalized.pop("checksum", None)

canonical = canonicalize(normalized)
raw = json.dumps(
    canonical,
    ensure_ascii=False,
    separators=(",", ":"),
).encode("utf-8")

checksum = hashlib.sha256(raw).hexdigest()
data["checksum"] = checksum

path.write_text(
    json.dumps(data, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8"
)

print(checksum)
'@

$TempPy = Join-Path $env:TEMP "fix_remote_checksum_temp.py"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($TempPy, $pythonCode, $Utf8NoBom)

try {
    $checksum = python $TempPy $JsonPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Falló el cálculo del checksum." -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "Checksum actualizado correctamente." -ForegroundColor Green
    Write-Host "Archivo: $JsonPath"
    Write-Host "Checksum: $checksum"
}
finally {
    if (Test-Path $TempPy) {
        Remove-Item $TempPy -Force
    }
}
